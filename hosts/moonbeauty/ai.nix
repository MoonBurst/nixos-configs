{ config, pkgs, ... }:

{
  # 1. Enable AMD OpenCL / ROCm hardware support
  hardware.amdgpu.opencl.enable = true;

  # 2. Add your user to GPU access groups
  users.users.moonburst.extraGroups = [ "video" "render" ];

  # 3. Set global environment variables for PyTorch + AMD ROCm
  environment.sessionVariables = {
    # CRITICAL FOR AMD GPUs:
    # Set this according to your GPU architecture:
    # - RX 6000 series (RDNA2): "10.3.0"
    # - RX 7000 series (RDNA3): "11.0.0" (or "11.0.2")
    HSA_OVERRIDE_GFX_VERSION = "10.3.0"; 

    # Prevents PyTorch from trying to use CUDA on AMD
    HIP_VISIBLE_DEVICES = "0";
    
    # Enable unified memory if needed
    HCC_AMDGPU_TARGET = "gfx1030";
  };

  # 4. System packages required to build/run ROCm PyTorch and Image Gen UIs
  environment.systemPackages = with pkgs; [
    # ROCm Diagnostic tools
    rocmPackages.rocminfo
    clinfo
    radeontop # Useful for monitoring AMD GPU usage

    # Build tools & Dependencies
    python311
    python311Packages.pip
    python311Packages.virtualenv
    git
    git-lfs
    wget
    ffmpeg

    # Standard C/C++ libraries needed by Python wheels
    stdenv.cc.cc.lib
    zlib
    glib
    libGL
    libglvnd
  ];

  # 5. Fix library paths system-wide for dynamically loaded Python binaries
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      glib
      libGL
      libglvnd
      rocmPackages.rocm-runtime
      rocmPackages.clr
    ];
  };
}
