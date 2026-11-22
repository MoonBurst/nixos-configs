{ config, pkgs, lib, inputs, ... }:

let
  # ============================================================================
  # SETTINGS
  # ============================================================================
  readspeed = "+20%";

  # Directory holding hubert.onnx, sage_gen.onnx, meta.json (exported once)
  onnxDir = "$HOME/.local/share/sage-tts/onnx";

  piperNative = pkgs.stdenv.mkDerivation rec {
    pname = "piper-tts-native";
    version = "2023.11.14-2";

    src = pkgs.fetchurl {
      url = "https://github.com/rhasspy/piper/releases/download/${version}/piper_linux_x86_64.tar.gz";
      sha256 = "sha256-pQy0XzVbevH211jBs2BxeHe6CjmMyMvm0qejom4iWZI=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/piper-native $out/bin
      cp -r . $out/share/piper-native/
      chmod +x $out/share/piper-native/piper
      ln -s $out/share/piper-native/piper $out/bin/piper
      runHook postInstall
    '';

    meta = {
      description = "Piper neural TTS — native C++ binary release (MIT, 2023.11.14-2)";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };

  pythonPkgs = pkgs.python3Packages;

  praatParselmouthPkg = pythonPkgs.buildPythonPackage rec {
    pname = "praat-parselmouth";
    version = "0.4.7";
    format = "wheel";
    src = pythonPkgs.fetchPypi {
      pname = "praat_parselmouth";
      inherit version format;
      dist = "cp313";
      python = "cp313";
      abi = "cp313";
      platform = "manylinux2014_x86_64.manylinux_2_17_x86_64";
      hash = "sha256-wi2fgJhOkRYuO+ExCWN/Xf4Q0spNOxXt1+eCVQumJ/E=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    propagatedBuildInputs = [ pythonPkgs.numpy ];
    doCheck = false;
    pythonImportsCheck = [ "parselmouth" ];
    meta.description = "Praat bindings used for pitch (F0) analysis";
  };

  # Slim environment: no torch, fairseq, librosa, numba or ROCm.
  # onnxruntime itself is loaded from ~/.local/share/sage-tts/ort (see worker).
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    numpy
    scipy
    soundfile
  ] ++ [ praatParselmouthPkg ]);

  # ============================================================================
  # PYTHON ONNX WORKER (voice conversion only; protocol over stdin/stdout)
  #   in:  "<input.wav>\t<output.wav>\n"
  #   out: "READY\n" once at startup, then "OK\n" or "ERR <msg>\n" per request
  # ============================================================================
  rvcWorkerScript = pkgs.writeText "sage-rvc-worker.py" ''
    import os
    import sys
    import json
    import math

    # onnxruntime lives in ~/.local; appended so the Nix numpy always wins
    sys.path.append(os.path.expanduser("~/.local/share/sage-tts/ort"))

    # Keep the protocol channel clean: library stdout goes to stderr (journalctl)
    proto = os.fdopen(os.dup(1), "w")
    os.dup2(2, 1)

    import numpy as np
    import onnxruntime as ort
    import soundfile as sf
    import parselmouth
    from scipy.signal import resample_poly

    D = os.environ["SAGE_ONNX_DIR"]
    META = json.load(open(D + "/meta.json"))

    so = ort.SessionOptions()
    so.intra_op_num_threads = int(os.environ.get("SAGE_ORT_THREADS", "4"))
    if os.environ.get("SAGE_ORT_LEAN") == "1":
        # trades some speed for lower memory growth
        so.enable_cpu_mem_arena = False
        so.enable_mem_pattern = False

    PROV = ["CPUExecutionProvider"]
    HUB = ort.InferenceSession(D + "/hubert.onnx", so, providers=PROV)
    GEN = ort.InferenceSession(D + "/sage_gen.onnx", so, providers=PROV)

    MMIN = 1127 * math.log(1 + 50 / 700)
    MMAX = 1127 * math.log(1 + 1100 / 700)


    def convert(src, dst):
        audio, sr = sf.read(src, dtype="float32")
        if audio.ndim > 1:
            audio = audio.mean(axis=1)
        if sr != 16000:
            g = math.gcd(sr, 16000)
            audio = resample_poly(audio, 16000 // g, sr // g).astype(np.float32)

        feats = HUB.run(None, {"source": audio[None, :]})[0]
        feats = np.repeat(feats, 2, axis=1)

        f0 = parselmouth.Sound(audio.astype(np.float64), 16000).to_pitch_ac(
            time_step=0.01, voicing_threshold=0.6,
            pitch_floor=50, pitch_ceiling=1100).selected_array["frequency"]
        n = min(feats.shape[1], len(f0))
        feats, f0 = feats[:, :n], f0[:n].astype(np.float32)

        mel = 1127 * np.log(1 + f0 / 700)
        v = mel > 0
        mel[v] = (mel[v] - MMIN) * 254 / (MMAX - MMIN) + 1
        coarse = np.rint(np.clip(mel, 1, 255)).astype(np.int64)[None, :]

        out = GEN.run(None, {
            "phone": feats.astype(np.float32),
            "lengths": np.array([n], dtype=np.int64),
            "pitch": coarse,
            "pitchf": f0[None, :],
            "sid": np.array([0], dtype=np.int64),
        })[0]
        sf.write(dst, out.reshape(-1), META["tgt_sr"])


    def main():
        print("READY", file=proto, flush=True)
        for line in sys.stdin:
            line = line.rstrip("\n")
            if not line:
                continue
            try:
                src, dst = line.split("\t", 1)
                convert(src, dst)
                print("OK", file=proto, flush=True)
            except Exception as e:
                print(f"ERR {e}", file=proto, flush=True)


    if __name__ == "__main__":
        main()
  '';

  # ============================================================================
  # RUST DAEMON (std only, no crates)
  # ============================================================================
  daemonSrc = pkgs.writeText "sage-daemon.rs" ''
    use std::collections::BTreeSet;
    use std::env;
    use std::fs;
    use std::io::{self, BufRead, BufReader, Read, Write};
    use std::os::unix::net::UnixListener;
    use std::path::{Path, PathBuf};
    use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
    use std::thread::sleep;
    use std::time::{Duration, Instant};

    const SOCKET_PATH: &str = "/tmp/sage_tts.sock";

    fn atempo_filter(speed: &str) -> String {
        let v: f64 = speed.trim().trim_end_matches('%').parse().unwrap_or(0.0);
        // ffmpeg's atempo only accepts 0.5..=2.0 per instance
        let m = (1.0 + v / 100.0).clamp(0.5, 2.0);
        format!("atempo={:.2}", m)
    }

    fn list_wavs(dir: &Path) -> BTreeSet<PathBuf> {
        let mut set = BTreeSet::new();
        if let Ok(rd) = fs::read_dir(dir) {
            for e in rd.flatten() {
                let p = e.path();
                if p.extension().map(|x| x == "wav").unwrap_or(false) {
                    set.insert(p);
                }
            }
        }
        set
    }

    // ---------------------------------------------------------------- Piper --

    struct Piper {
        model: String,
        out_dir: PathBuf,
        child: Child,
        stdin: ChildStdin,
    }

    fn ensure_piper_model(model: &str) {
        if Path::new(model).exists() {
            return;
        }
        if let Some(parent) = Path::new(model).parent() {
            let _ = fs::create_dir_all(parent);
        }
        eprintln!("Downloading fast local Piper voice model...");
        let base = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx";
        let _ = Command::new("curl").args(["-s", "-L", base, "-o", model]).status();
        let _ = Command::new("curl")
            .args(["-s", "-L", &format!("{}.json", base), "-o", &format!("{}.json", model)])
            .status();
    }

    fn cleanup_stale_piper_dirs() {
        if let Ok(rd) = fs::read_dir("/tmp") {
            for e in rd.flatten() {
                if e.file_name().to_string_lossy().starts_with("sage_piper_") {
                    let _ = fs::remove_dir_all(e.path());
                }
            }
        }
    }

    impl Piper {
        fn start(model: &str) -> io::Result<Piper> {
            ensure_piper_model(model);
            cleanup_stale_piper_dirs();
            let out_dir = PathBuf::from(format!("/tmp/sage_piper_{}", std::process::id()));
            fs::create_dir_all(&out_dir)?;

            let mut child = Command::new("piper")
                .args(["--model", model, "--output_dir"])
                .arg(&out_dir)
                .stdin(Stdio::piped())
                .stdout(Stdio::null())
                .stderr(Stdio::inherit())
                .spawn()?;
            let stdin = child.stdin.take().expect("piper stdin");
            eprintln!("Resident Piper process started (model loaded once, reused per call).");
            Ok(Piper { model: model.to_string(), out_dir, child, stdin })
        }

        fn restart(&mut self) -> bool {
            let _ = self.child.kill();
            let _ = self.child.wait();
            match Piper::start(&self.model.clone()) {
                Ok(p) => {
                    *self = p;
                    true
                }
                Err(e) => {
                    eprintln!("[Piper Error] restart failed: {}", e);
                    false
                }
            }
        }

        fn send_line(&mut self, text: &str) -> io::Result<()> {
            let line = format!("{}\n", text.replace('\n', " "));
            self.stdin.write_all(line.as_bytes())?;
            self.stdin.flush()
        }

        /// Feed one line to the resident piper and wait for its wav to land.
        /// Requests are handled sequentially, so arrival order == request order.
        fn synth(&mut self, text: &str) -> Option<PathBuf> {
            if let Ok(Some(_)) = self.child.try_wait() {
                if !self.restart() {
                    return None;
                }
            }

            let before = list_wavs(&self.out_dir);

            if self.send_line(text).is_err() {
                if !self.restart() || self.send_line(text).is_err() {
                    return None;
                }
            }

            let deadline = Instant::now() + Duration::from_secs(10);
            let mut new_file: Option<PathBuf> = None;
            while Instant::now() < deadline {
                let after = list_wavs(&self.out_dir);
                if let Some(p) = after.difference(&before).next() {
                    new_file = Some(p.clone());
                    break;
                }
                sleep(Duration::from_millis(10));
            }

            let Some(file) = new_file else {
                eprintln!("[Piper Warning] timed out waiting for output wav (text: {:?})", text);
                return None;
            };

            // Wait for the file size to stabilise so we don't read a half-written wav.
            let mut last: i64 = -1;
            let mut stable = 0;
            let stability_deadline = Instant::now() + Duration::from_secs(2);
            while Instant::now() < stability_deadline {
                let size = fs::metadata(&file).map(|m| m.len() as i64).unwrap_or(-1);
                if size == last && size > 0 {
                    stable += 1;
                    if stable >= 2 {
                        break;
                    }
                } else {
                    stable = 0;
                }
                last = size;
                sleep(Duration::from_millis(20));
            }
            Some(file)
        }
    }

    // ------------------------------------------------------------ RVC worker --

    struct Worker {
        child: Child,
        stdin: ChildStdin,
        stdout: BufReader<ChildStdout>,
    }

    impl Worker {
        fn start() -> io::Result<Worker> {
            let python = env::var("SAGE_PYTHON").expect("SAGE_PYTHON not set");
            let script = env::var("SAGE_WORKER").expect("SAGE_WORKER not set");
            let mut child = Command::new(python)
                .arg(script)
                .stdin(Stdio::piped())
                .stdout(Stdio::piped())
                .stderr(Stdio::inherit())
                .spawn()?;
            let stdin = child.stdin.take().expect("worker stdin");
            let mut stdout = BufReader::new(child.stdout.take().expect("worker stdout"));

            loop {
                let mut line = String::new();
                if stdout.read_line(&mut line)? == 0 {
                    return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "worker exited before READY"));
                }
                if line.trim() == "READY" {
                    break;
                }
            }
            Ok(Worker { child, stdin, stdout })
        }

        fn infer_once(&mut self, src: &Path, dst: &Path) -> io::Result<bool> {
            writeln!(self.stdin, "{}\t{}", src.display(), dst.display())?;
            self.stdin.flush()?;
            let mut line = String::new();
            if self.stdout.read_line(&mut line)? == 0 {
                return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "worker died"));
            }
            if !line.starts_with("OK") {
                eprintln!("[Worker] {}", line.trim());
            }
            Ok(line.starts_with("OK"))
        }

        /// Run inference; if the worker died, restart it once and retry.
        fn infer(&mut self, src: &Path, dst: &Path) -> bool {
            match self.infer_once(src, dst) {
                Ok(ok) => ok,
                Err(e) => {
                    eprintln!("[Worker] {} — restarting", e);
                    let _ = self.child.kill();
                    let _ = self.child.wait();
                    match Worker::start() {
                        Ok(w) => {
                            *self = w;
                            self.infer_once(src, dst).unwrap_or(false)
                        }
                        Err(e) => {
                            eprintln!("[Worker Error] restart failed: {}", e);
                            false
                        }
                    }
                }
            }
        }
    }

    // --------------------------------------------------------------- Pipeline --

    fn generate_base_speech(piper: &mut Piper, text: &str, atempo: &str, out_wav: &Path) -> bool {
        let text = text.trim();
        if text.is_empty() {
            return false;
        }
        let mut clean = text.to_string();
        if !clean.ends_with(['.', '!', '?']) {
            clean.push('.');
        }

        let Some(raw) = piper.synth(&clean) else { return false };

        let out = Command::new("ffmpeg")
            .args(["-y", "-i"])
            .arg(&raw)
            .args(["-filter:a", atempo, "-ar", "16000", "-ac", "1"])
            .arg(out_wav)
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .output();
        match out {
            Ok(o) if !o.status.success() => {
                let err = String::from_utf8_lossy(&o.stderr);
                let tail: String = err.chars().rev().take(500).collect::<Vec<_>>().into_iter().rev().collect();
                eprintln!("[Piper Warning] ffmpeg failed: {}", tail);
            }
            Err(e) => eprintln!("[Piper Warning] could not run ffmpeg: {}", e),
            _ => {}
        }
        let _ = fs::remove_file(&raw);

        fs::metadata(out_wav).map(|m| m.len() > 100).unwrap_or(false)
    }

    fn speak(text: &str, piper: &mut Piper, worker: &mut Worker, atempo: &str, play: bool, n: u64) {
        let tmp = PathBuf::from(format!("/tmp/sage_req_{}_{}", std::process::id(), n));
        if fs::create_dir_all(&tmp).is_err() {
            return;
        }
        let base = tmp.join("base.wav");
        let sage = tmp.join("sage_output.wav");

        let t0 = Instant::now();
        if generate_base_speech(piper, text, atempo, &base) {
            let t1 = Instant::now();
            if worker.infer(&base, &sage) {
                let t2 = Instant::now();
                eprintln!(
                    "[INSTANT VOICE TIMING] Base Speech (piper): {:.3}s | Sage RVC: {:.3}s | Total: {:.3}s",
                    (t1 - t0).as_secs_f64(),
                    (t2 - t1).as_secs_f64(),
                    (t2 - t0).as_secs_f64()
                );
                if play && fs::metadata(&sage).map(|m| m.len() > 0).unwrap_or(false) {
                    let _ = Command::new("pw-play").arg(&sage).status();
                }
            }
        }
        let _ = fs::remove_dir_all(&tmp);
    }

    fn main() {
        let piper_model = env::var("SAGE_PIPER_MODEL").expect("SAGE_PIPER_MODEL not set");
        let readspeed = env::var("SAGE_READSPEED").unwrap_or_else(|_| "+0%".into());
        let atempo = atempo_filter(&readspeed);

        let _ = fs::remove_file(SOCKET_PATH);
        let listener = UnixListener::bind(SOCKET_PATH).expect("failed to bind socket");

        eprintln!("Starting Sage daemon | Speed: {} ({})", readspeed, atempo);

        let mut piper = Piper::start(&piper_model).expect("failed to start piper");
        let mut worker = Worker::start().expect("failed to start RVC worker");

        eprintln!("Pre-warming pipelines...");
        speak("System ready.", &mut piper, &mut worker, &atempo, false, 0);
        eprintln!("Sage Voice Model pre-loaded! Ready for notifications!");

        let mut counter: u64 = 1;
        for conn in listener.incoming() {
            let mut stream = match conn {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("[Sage Daemon Error] accept: {}", e);
                    continue;
                }
            };
            let mut buf = String::new();
            // Client sends then closes; cap input at 4 KiB like the original.
            if Read::by_ref(&mut stream).take(4096).read_to_string(&mut buf).is_err() {
                continue;
            }
            drop(stream);

            let text = buf.trim();
            if text.is_empty() {
                continue;
            }
            speak(text, &mut piper, &mut worker, &atempo, true, counter);
            counter += 1;
        }
    }
  '';

  clientSrc = pkgs.writeText "sage-client.rs" ''
    use std::io::Write;
    use std::os::unix::net::UnixStream;

    fn main() {
        let text = std::env::args().skip(1).collect::<Vec<_>>().join(" ");
        match UnixStream::connect("/tmp/sage_tts.sock") {
            Ok(mut s) => {
                let _ = s.write_all(text.as_bytes());
            }
            Err(_) => {
                eprintln!("Sage daemon not running!");
                std::process::exit(1);
            }
        }
    }
  '';

  sageRs = pkgs.stdenv.mkDerivation {
    pname = "sage-tts-rs";
    version = "0.1.0";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.rustc ];
    buildPhase = ''
      runHook preBuild
      rustc -O --edition 2021 ${daemonSrc} -o sage-daemon-rs
      rustc -O --edition 2021 ${clientSrc} -o sage-tts
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 sage-daemon-rs $out/bin/sage-daemon-rs
      install -m755 sage-tts $out/bin/sage-tts
      runHook postInstall
    '';
  };

  sage-daemon = pkgs.writeShellScriptBin "sage-daemon" ''
    export PYTHONUNBUFFERED=1
    export PATH="${piperNative}/bin:${pkgs.curl}/bin:${pkgs.pipewire}/bin:${pkgs.ffmpeg}/bin:$PATH"
    export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:$LD_LIBRARY_PATH"

    export SAGE_PYTHON="${pythonEnv}/bin/python3"
    export SAGE_WORKER="${rvcWorkerScript}"
    export SAGE_ONNX_DIR="${onnxDir}"
    export SAGE_PIPER_MODEL="$HOME/.local/share/sage-tts/piper/en_US-amy-medium.onnx"
    export SAGE_READSPEED="${readspeed}"

    # Uncomment to cap ONNX memory growth at some cost in speed:
    # export SAGE_ORT_LEAN=1

    exec ${sageRs}/bin/sage-daemon-rs "$@"
  '';

  sage-client = pkgs.writeShellScriptBin "sage-tts" ''
    exec ${sageRs}/bin/sage-tts "$@"
  '';

  sage-tts-suite = pkgs.symlinkJoin {
    name = "sage-tts-suite";
    paths = [ sage-daemon sage-client ];
  };
in
{
  environment.systemPackages = [ sage-tts-suite ];

  systemd.user.services.sage-daemon = {
    description = "Sage AI Voice TTS Daemon";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${sage-daemon}/bin/sage-daemon";
      Restart = "always";
      RestartSec = 3;
    };
  };
}
