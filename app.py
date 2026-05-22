import cv2
import requests
import numpy as np
import time
from ultralytics import YOLO
import firebase_admin
from firebase_admin import credentials
from firebase_admin import db

# ================= CẤU HÌNH IP VÀ FIREBASE =================
ESP_MAIN_IP = "http://192.168.2.16"  
ESP_CAM_IP = "http://192.168.2.14"

# Khởi tạo kết nối Firebase
print("Đang kết nối Firebase...")
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred, {
        # THAY BẰNG LINK DATABASE CỦA BẠN NHÉ
        'databaseURL': 'https://smarttrashiot-d7d2c-default-rtdb.asia-southeast1.firebasedatabase.app'
    })
    ref_trang_thai = db.reference('TrangThaiThungRac')
    ref_thong_ke = db.reference('ThongKeAI')
    print("Kết nối Firebase thành công!")
except Exception as e:
    print("Lỗi kết nối Firebase:", e)

# Load mô hình YOLO
print("Đang load model YOLO...")
model = YOLO('trash.pt')
print("Load thanh cong! Dang lang nghe ESP32...")

def lay_anh_tu_camera():
    try:
        url = f"{ESP_CAM_IP}/capture"
        response = requests.get(url, timeout=5)
        img_array = np.array(bytearray(response.content), dtype=np.uint8)
        img = cv2.imdecode(img_array, -1)
        return img
    except Exception as e:
        print("Loi ket noi Camera:", e)
        return None

def phan_loai_va_gui_lenh(img):
    results = model(img)
    loai_rac = "V" 
    ten_rac = "Khong xac dinh"

    for r in results:
        boxes = r.boxes
        for box in boxes:
            class_id = int(box.cls[0])
            confidence = float(box.conf[0])
            
            if confidence > 0.5:
                class_name = model.names[class_id]
                ten_rac = class_name
                
                if class_name in ["Organic", "organic", "Huu_co"]:
                    loai_rac = "H" 
                else:
                    loai_rac = "V" 
                break

    print(f"-> Nhan dien: {ten_rac}. Gui lenh: {loai_rac}")
    
    # 1. Gửi lệnh phân loại xuống ESP32
    try:
        requests.get(f"{ESP_MAIN_IP}/{loai_rac}", timeout=5)
        print("-> Da gui lenh gạt khay thanh cong!")
    except Exception as e:
        print("Loi ket noi voi ESP32 Chinh:", e)
        
    # 2. Đẩy dữ liệu số lượng AI lên Firebase
    try:
        if loai_rac == "H":
            so_cu = ref_thong_ke.child('SoLuongHuuCo').get() or 0
            ref_thong_ke.update({'SoLuongHuuCo': so_cu + 1})
        else:
            so_cu = ref_thong_ke.child('SoLuongVoCo').get() or 0
            ref_thong_ke.update({'SoLuongVoCo': so_cu + 1})
        print("-> Đã cập nhật số lượng đếm lên Firebase App!\n")
    except Exception as e:
        print("Lỗi đẩy số lượng lên Firebase:", e)

# ================= VÒNG LẶP CHÍNH =================
while True:
    try:
        # Lấy gói dữ liệu từ ESP32 (Dạng: "SCAN,Binh Thuong,DA DAY")
        res = requests.get(f"{ESP_MAIN_IP}/status", timeout=2)
        data = res.text.strip().split(',')
        
        # Nếu ESP32 gửi đúng định dạng 3 phần
        if len(data) == 3:
            scan_flag = data[0]
            status_huu_co = data[1]
            status_vo_co = data[2]
            
            # CẬP NHẬT TRẠNG THÁI RÁC ĐẦY LÊN FIREBASE LIÊN TỤC
            ref_trang_thai.update({
                'HuuCo': status_huu_co,
                'VoCo': status_vo_co
            })
            
            # Nếu có người vứt rác thì chụp ảnh
            if scan_flag == "SCAN":
                print("\n!!! PHAT HIEN RAC MOI !!!")
                print("Tien hanh chup anh...")
                
                img = lay_anh_tu_camera()
                if img is not None:
                    cv2.imshow("Camera Thung Rac", img)
                    cv2.waitKey(1)
                    phan_loai_va_gui_lenh(img)
                    
                time.sleep(2) 
            
    except requests.exceptions.RequestException:
        pass 
        
    time.sleep(1)