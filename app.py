import cv2
import requests
import numpy as np
import time
from ultralytics import YOLO

# ================= CẤU HÌNH IP =================
# Sửa lại thành thế này:
ESP_MAIN_IP = "http://192.168.2.16"  
ESP_CAM_IP = "http://192.168.2.14"

# Load mô hình YOLO
print("Đang load model YOLO...")
model = YOLO('trash.pt')
print("Load thanh cong! Dang lang nghe ESP32...")

def lay_anh_tu_camera():
    try:
        # Tải ảnh từ ESP32-CAM
        url = f"{ESP_CAM_IP}/capture"
        response = requests.get(url, timeout=5)
        # Chuyển đổi dữ liệu ảnh thành định dạng OpenCV
        img_array = np.array(bytearray(response.content), dtype=np.uint8)
        img = cv2.imdecode(img_array, -1)
        return img
    except Exception as e:
        print("Loi ket noi Camera:", e)
        return None

def phan_loai_va_gui_lenh(img):
    # Chạy AI
    results = model(img)
    
    # Mặc định là Vô cơ nếu AI không nhận ra
    loai_rac = "V" 
    ten_rac = "Khong xac dinh"

    # Đọc kết quả từ YOLOv8
    for r in results:
        boxes = r.boxes
        for box in boxes:
            class_id = int(box.cls[0])
            confidence = float(box.conf[0])
            
            # Chỉ lấy kết quả có độ tin cậy > 50%
            if confidence > 0.5:
                class_name = model.names[class_id] # Lấy tên nhãn từ model
                ten_rac = class_name
                
                # Kiểm tra nhãn khớp với Roboflow (thường là Organic/Inorganic)
                if class_name in ["Organic", "organic", "Huu_co"]:
                    loai_rac = "H" # Gửi lệnh H cho Hữu cơ
                else:
                    loai_rac = "V" # Gửi lệnh V cho Vô cơ
                break

    print(f"-> Nhan dien: {ten_rac}. Gui lenh: {loai_rac}")
    
    # Gửi lệnh phân loại xuống ESP32 chính
    try:
        requests.get(f"{ESP_MAIN_IP}/{loai_rac}", timeout=5)
        print("-> Da gui lenh phan loai thanh cong!\n")
    except Exception as e:
        print("Loi ket noi voi ESP32 Chinh:", e)

# ================= VÒNG LẶP CHÍNH =================
while True:
    try:
        # 1. Hỏi ESP32 chính xem đã có rác vào khay chưa?
        res = requests.get(f"{ESP_MAIN_IP}/status", timeout=2)
        status = res.text.strip()
        
        if "SCAN" in status:
            print("\n!!! PHAT HIEN RAC MOI !!!")
            print("Tien hanh chup anh...")
            
            img = lay_anh_tu_camera()
            if img is not None:
                # Hiển thị ảnh (tùy chọn)
                cv2.imshow("Camera Thung Rac", img)
                cv2.waitKey(1)
                
                # Phân loại và gạt khay
                phan_loai_va_gui_lenh(img)
                
            time.sleep(2) # Chờ khay gạt xong mới quét tiếp
            
    except requests.exceptions.RequestException:
        pass # Bỏ qua nếu mất mạng chập chờn
        
    time.sleep(1) # Cứ 1 giây hỏi trạng thái 1 lần