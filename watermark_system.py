import os
import sys
import subprocess
import tempfile

with tempfile.TemporaryDirectory() as tmpdir:
    sys.path.insert(0, tmpdir)
    try:
        import blind_watermark
    except ImportError:
        print("Bootstrapping package dependencies safely")
        subprocess.check_call([
            sys.executable, "-m", "pip", "install", 
            "--target", tmpdir, "blind-watermark", "--no-deps", "--quiet"
        ])
        from blind_watermark import WaterMark

    import numpy as np
    import cv2

    print(f"Sandbox container running at {tmpdir}")
    src_path = os.path.join(tmpdir, "source.jpg")
    embedded_path = os.path.join(tmpdir, "embedded.jpg")
    cropped_path = os.path.join(tmpdir, "cropped.jpg")
    
    user_tracking_name = "User_Alice_99"
    print(f"Tracking Name Target: {user_tracking_name}")
    
    binary_string = ''.join(format(ord(c), '08b') for c in user_tracking_name)
    bit_array_map = [char == '1' for char in binary_string]
    bit_count = len(bit_array_map)
    print(f"Total tracking bits mapped to frequency matrices: {bit_count}")

    canvas = np.zeros((1024, 1024, 3), dtype=np.uint8)
    for y in range(1024):
        for x in range(1024):
            canvas[y, x] = [(x * 7) % 255, (y * 3) % 255, (x + y) % 255]
    cv2.putText(canvas, "INTERNAL AUDIT SYSTEM STREAM ACTIVE", (100, 500), 
                cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 255), 3)
    cv2.imwrite(src_path, canvas, [int(cv2.IMWRITE_JPEG_QUALITY), 95])

    print("Embedding tracking bits globally across matrix structures")
    bwm = WaterMark(password_wm=100, password_img=100)
    bwm.read_img(src_path)
    bwm.read_wm(bit_array_map, mode='bit')
    bwm.embed(embedded_path)

    print("Simulating adversarial crop attack (Slicing canvas down to 512x512)")
    watermarked_img = cv2.imread(embedded_path)
    cropped_img = watermarked_img[0:512, 0:512] 
    cv2.imwrite(cropped_path, cropped_img, [int(cv2.IMWRITE_JPEG_QUALITY), 90])

    print("Extracting tracking array shapes from fragment spectrum")
    bwm_extract = WaterMark(password_wm=100, password_img=100)
    
    # Corrected: wm_shape is passed explicitly to the extract method
    extracted_float_bits = bwm_extract.extract(cropped_path, wm_shape=bit_count, mode='bit')
    
    reconstructed_binary = ""
    for weight in extracted_float_bits:
        if weight >= 0.5:
            reconstructed_binary += "1"
        else:
            reconstructed_binary += "0"
            
    decoded_chars = []
    for i in range(0, len(reconstructed_binary), 8):
        byte_segment = reconstructed_binary[i:i+8]
        if len(byte_segment) == 8:
            decoded_chars.append(chr(int(byte_segment, 2)))
            
    final_recovered_name = "".join(decoded_chars)

    print("\n================ SYSTEM MATRIX ANALYSIS ================")
    print(f"Original Text Key: {user_tracking_name}")
    print(f"Recovered Text Key: {final_recovered_name}")
    
    if final_recovered_name == user_tracking_name:
        print("🏆 SUCCESS: Frequency bit mapping bypassed crop degradation completely!")
    else:
        print("⚠️ Noise variance detected in pixel blocks.")
    print("========================================================\n")

print("Destroying local container cache files")
