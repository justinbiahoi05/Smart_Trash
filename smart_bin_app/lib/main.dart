import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

// ĐÂY LÀ LINK DATABASE CỦA BẠN (ASIA-SOUTHEAST1)
const String DB_URL = "https://smarttrashiot-d7d2c-default-rtdb.asia-southeast1.firebasedatabase.app";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print("====== ĐANG KHỞI TẠO FIREBASE ======");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("====== KHỞI TẠO FIREBASE THÀNH CÔNG! ======");
  } catch (e) {
    print("====== LỖI KHỞI TẠO FIREBASE: $e ======");
  }
  runApp(const SmartBinApp());
}

class SmartBinApp extends StatelessWidget {
  const SmartBinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Bin IoT',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF4F9F4),
        fontFamily: 'Roboto',
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DatabaseReference _dbRef;

  @override
  void initState() {
    super.initState();
    print("====== BẮT ĐẦU KẾT NỐI DATABASE ======");
    
    // BÍ KÍP TRỊ LỖI KẸT SERVER SINGAPORE: Ép buộc trỏ đúng link URL
    _dbRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: DB_URL,
    ).ref();

    // Lệnh này để test đọc thử 1 lần xem có bị chặn quyền không
    _dbRef.get().then((snapshot) {
      if (snapshot.exists) {
        print("====== TEST ĐỌC THÀNH CÔNG! Dữ liệu: ${snapshot.value} ======");
      } else {
        print("====== TEST ĐỌC THÀNH CÔNG NHƯNG DATA RỖNG ======");
      }
    }).catchError((error) {
      print("====== LỖI KHÔNG ĐỌC ĐƯỢC DATA: $error ======");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFA8E6CF),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'SMART BIN DASHBOARD',
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
      body: StreamBuilder(
        stream: _dbRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          
          // In trạng thái Stream ra Debug Console
          print("Trạng thái Stream: ${snapshot.connectionState}");

          if (snapshot.hasError) {
            print("LỖI STREAM: ${snapshot.error}");
            return Center(child: Text("Lỗi Firebase: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            // Thay vì chỉ xoay tròn, in thêm chữ ra màn hình
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Đang kết nối tới Firebase...", style: TextStyle(fontSize: 16)),
                  Text("(Hãy kiểm tra tab DEBUG CONSOLE trên VS Code)"),
                ],
              ),
            );
          }

          // In dữ liệu thực tế lấy được ra Debug Console
          print("Dữ liệu nhận được: ${snapshot.data?.snapshot.value}");

          final data = (snapshot.data?.snapshot.value as Map<dynamic, dynamic>?) ?? {};
          
          final trangThai = data['TrangThaiThungRac'] ?? {};
          String statusHuuCo = trangThai['HuuCo']?.toString() ?? "Binh Thuong";
          String statusVoCo = trangThai['VoCo']?.toString() ?? "Binh Thuong";

          final thongKe = data['ThongKeAI'] ?? {};
          int countHuuCo = int.tryParse(thongKe['SoLuongHuuCo']?.toString() ?? '0') ?? 0;
          int countVoCo = int.tryParse(thongKe['SoLuongVoCo']?.toString() ?? '0') ?? 0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Trạng thái ngăn chứa",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _buildStatusCard("Ngăn Hữu Cơ", statusHuuCo)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildStatusCard("Ngăn Vô Cơ", statusVoCo)),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  "Thống kê AI Phân loại",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _buildStatCard("Rác Hữu Cơ", countHuuCo.toString(), Icons.eco, const Color(0xFFDCEDC1))),
                    const SizedBox(width: 15),
                    Expanded(child: _buildStatCard("Rác Vô Cơ", countVoCo.toString(), Icons.delete_outline, const Color(0xFFFFD3B6))),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(String title, String status) {
    bool isFull = status == "DA DAY";
    Color cardColor = isFull ? const Color(0xFFFF8A80) : Colors.white;
    Color textColor = isFull ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 10),
          Icon(isFull ? Icons.warning_amber_rounded : Icons.check_circle_outline, 
              size: 40, color: textColor),
          const SizedBox(height: 10),
          Text(
            isFull ? "ĐÃ ĐẦY" : "Bình thường",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 35, color: Colors.black54),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 5),
          Text(
            count,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const Text("vật thể", style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}