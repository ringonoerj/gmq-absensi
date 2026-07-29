# GMQ Absensi V2 - Sistem Manajemen Kehadiran Sekolah

Sistem Manajemen Kehadiran (Absensi) Sekolah berbasis Flutter (Frontend) dan Supabase (Backend/Database) yang dirancang untuk mendukung pencatatan kehadiran guru dan siswa secara efisien, baik secara online maupun offline dengan caching lokal (Hive) dan sinkronisasi otomatis.

Proyek ini merupakan solusi terintegrasi yang mencakup aplikasi mobile/web multiplatform (Flutter), basis data relasional (Postgres di Supabase), diagram alur sistem komprehensif, serta skrip otomatisasi & diagnostik berbasis Node.js.

---

## 📌 Fitur Utama

- **Role-Based Access Control (RBAC)**:
  - **Operator**: Mencatat kehadiran harian guru & siswa (mendukung pencatatan offline dengan sinkronisasi otomatis).
  - **Supervisor**: Melihat laporan kehadiran, statistik visual, grafik, dan mengekspor data ke Excel/PDF.
  - **Superadmin**: Manajemen master-data penuh (Unit Pendidikan, Kelas, Guru, Siswa, Pengguna), konfigurasi insentif harian guru, serta proses backup/restore data.
- **Pencatatan Kehadiran Multi-Profil**: Guru dan siswa dapat terdaftar dan mencatat kehadiran di beberapa unit pendidikan atau kelas yang berbeda dalam hari yang sama.
- **Validasi Hari Libur (Nasional & Spesifik Unit)**: Validasi otomatis terhadap tabel `libur_nasional`. Input kehadiran akan diblokir pada tanggal libur dengan menampilkan status "Libur".
- **Metrik Laporan Komprehensif (H, I, S, A, L)**: Tampilan rekapitulasi kehadiran dengan 5 status utama: **Hadir (H), Izin (I), Sakit (S), Alpha (A), dan Libur (L)**. Dioptimalkan dengan batch loading untuk mencegah masalah performa *N+1 queries*.
- **Standardisasi Urutan A-Z**: Semua menu pilihan (dropdown), tampilan daftar, dan ringkasan data diurutkan secara alfabetis menaik (A-Z) untuk kemudahan pencarian.
- **Offline Caching & Auto-Sync**: Sinkronisasi data menggunakan Hive untuk menyimpan antrean input absensi saat tidak ada koneksi internet, lalu menyinkronkannya secara otomatis saat online kembali.
- **Spanduk Pengumuman & Grafik Dinamis**: Dasbor interaktif dengan grafik kehadiran waktu-nyata (real-time) dan spanduk informasi (banner) sistem yang dapat dikonfigurasi melalui panel admin.

---

## 📂 Struktur Repositori

```text
GMQ-ABSENSI-V2/
├── .github/workflows/          # Alur CI/CD GitHub Actions
│   └── firebase-hosting-merge.yml
├── gmq_absensi/                # Aplikasi Utama (Flutter & Dart)
│   ├── android/                # Konfigurasi Platform Android
│   ├── assets/                 # Aset Gambar & Ikon Aplikasi
│   ├── lib/                    # Logika Utama Flutter
│   │   ├── helpers/            # Helper fungsi (format tanggal, ekspor spreadsheet, dll.)
│   │   ├── models/             # Representasi Data Objek (Siswa, Guru, Unit, dll.)
│   │   ├── providers/          # Manajemen State (Provider)
│   │   ├── screens/            # Halaman / UI Screens
│   │   ├── services/           # Penghubung Supabase & Hive
│   │   ├── utils/              # Konstanta dan Tema Desain
│   │   └── widgets/            # Komponen UI Reusable
│   ├── web/                    # Konfigurasi Platform Web
│   ├── pubspec.yaml            # Dependensi Flutter
│   └── README.md               # README khusus aplikasi Flutter
├── migration.sql               # Skrip SQL Migrasi Basis Data
├── run_migration.js            # Skrip Migrasi DB otomatis menggunakan Node.js (pg)
├── test_all_db_conns.js        # Skrip diagnostik koneksi database Supabase
├── inspect_absensi_schema.js   # Skrip analisis skema tabel 'absensi'
├── dns_resolve.js              # Skrip pengujian resolusi DNS IPv4
├── dns_resolve6.js             # Skrip pengujian resolusi DNS IPv6
├── Diagram 1 s/d 14 .drawio    # Diagram arsitektur dan alur kerja sistem (Draw.io)
├── gmq-absensi-kredensial.txt  # Informasi referensi proyek & setup kredensial
└── package.json                # Dependensi Skrip Node.js (pg)
```

---

## 💻 Teknologi yang Digunakan

### **Frontend (Aplikasi Flutter)**
- **Flutter SDK**: `>=3.0.0 <4.0.0`
- **State Management**: Provider (`provider: ^6.0.5`)
- **Database & Auth**: Supabase Flutter SDK (`supabase_flutter: ^2.0.0`)
- **Penyimpanan Lokal**: Hive (`hive_flutter: ^1.1.0`) & SharedPreferences
- **Ekspor Dokumen**: Excel (`excel: ^2.0.0`) & PDF (`pdf: ^3.10.4`)
- **Konektivitas**: Connectivity Plus (`connectivity_plus: ^5.0.2`)

### **Backend & Basis Data**
- **Supabase / PostgreSQL**: Layanan database relasional cloud.
- **Node.js**: Backend helper scripts (menggunakan pustaka `pg` untuk mengelola koneksi database secara langsung).
- **Firebase Hosting**: Hosting web untuk aplikasi Flutter Web.

---

## 📐 Diagram Alur Sistem (Draw.io)
Repositori ini menyediakan 14 file diagram `.drawio` yang mendokumentasikan setiap alur sistem secara visual. Anda dapat membukanya menggunakan [Draw.io](https://app.diagrams.net/):

1. **Diagram 1 - Login Flow**: Alur autentikasi pengguna dan pemuatan sesi.
2. **Diagram 2 - Logout Flow**: Pembersihan sesi dan cache lokal.
3. **Diagram 3 - Load Data with Hierarchy**: Pemuatan hierarki data (Unit -> Kelas -> Siswa).
4. **Diagram 4 - Save Absensi Hadir**: Pencatatan kehadiran dan sinkronisasi real-time.
5. **Diagram 5 - Save Absensi Izin**: Pencatatan status izin/sakit dengan metadata pendukung.
6. **Diagram 6 - Load Laporan Per User**: Penyaringan laporan perorangan.
7. **Diagram 7 - Load Laporan Summary**: Pemuatan data statistik agregat dasbor.
8. **Diagram 8 - Export Laporan**: Alur konversi data ke format Excel spreadsheet dan PDF.
9. **Diagram 9 - CRUD Unit Pendidikan**: Pengelolaan data sekolah tingkat cabang/unit.
10. **Diagram 10 - CRUD Kelas**: Pengelolaan data kelas pada masing-masing unit.
11. **Diagram 11 - CRUD Guru**: Pengelolaan profil guru dan relasi multi-unit.
12. **Diagram 12 - CRUD Siswa**: Pengelolaan data siswa beserta nama wali.
13. **Diagram 13 - CRUD User & Role**: Pengaturan hak akses (Superadmin, Supervisor, Operator).
14. **Diagram 14 - Backup & Restore Data**: Proses ekspor-impor database untuk keperluan cadangan.

---

## 🗄️ Skema Database Supabase

Berikut adalah daftar tabel utama dan kolom penting dalam database Supabase (`public` schema) proyek GMQ Absensi V2:

### **1. Tabel Master Data**

| Nama Tabel | Deskripsi | Kolom Utama / Penting |
| :--- | :--- | :--- |
| `users` | Akun pengguna sistem (Admin/Operator) | `id` (UUID, PK), `email` (Text, Unique), `name` (Text), `role` (Text), `unit_id` (FK), `is_active` (Boolean) |
| `unit_pendidikan` | Data cabang/unit sekolah | `id` (Serial, PK), `name` (Text, Unique), `alamat` (Text), `kontak` (Text), `logo_url` (Text) |
| `kelas` | Data kelas di masing-masing unit | `id` (Serial, PK), `name` (Text), `unit_id` (FK), `tingkat` (Text), `jurusan` (Text) |
| `siswa` | Data profil siswa sekolah | `id` (Serial, PK), `nis` (Text, Unique), `name` (Text), `email` (Text), `no_telp` (Text), `unit_id` (FK), `kelas_id` (FK), `kategori_id` (FK), `nama_wali` (Text) |
| `guru` | Data profil guru sekolah | `id` (Serial, PK), `nip` (Text, Unique), `name` (Text), `email` (Text), `no_telp` (Text), `unit_id` (FK), `kategori_id` (FK), `unit_ids` (ARRAY / GIN index), `kelas_ids` (ARRAY / GIN index) |

### **2. Tabel Operasional & Transaksi**

| Nama Tabel | Deskripsi | Kolom Utama / Penting |
| :--- | :--- | :--- |
| `absensi` | Catatan kehadiran harian guru/siswa | `id` (Serial, PK), `user_type` (Text: 'siswa'/'guru'), `user_id` (Int), `date` (Date), `status` (Text: H/I/S/A/L), `izin_reason` (Text), `recorded_by` (UUID, FK), `unit_id` (Int, FK), `kelas_id` (Int, FK) |
| `insentif_guru` | Tarif insentif harian guru per unit | `id` (Serial, PK), `guru_id` (Int, FK), `unit_id` (Int, FK), `nominal` (Int), `UNIQUE(guru_id, unit_id)` |
| `libur_nasional` | Kalender libur nasional / sekolah | `id` (Serial, PK), `name` (Text), `tanggal` (Date), `keterangan` (Text), `unit_id` (FK), `UNIQUE(tanggal, unit_id)` |
| `kategori` | Kategori penanda jenis guru/siswa | `id` (Serial, PK), `name` (Text, Unique), `tipe` (Text) |
| `tahun_ajaran` | Periode tahun ajaran sekolah | `id` (Serial, PK), `name` (Text), `is_active` (Boolean), `tanggal_mulai` (Date), `tanggal_selesai` (Date) |
| `app_settings` | Setelan konfigurasi dinamis sistem | `key` (Text, PK), `value` (Text), `updated_at` (Timestamp) |
| `backup_logs` | Catatan riwayat pencadangan data | `id` (Serial, PK), `action` (Text), `filename` (Text), `performed_by` (UUID, FK) |

*Detail struktur teknis selengkapnya berformat JSON dapat diakses langsung pada berkas [`db_schema.json`](./db_schema.json) di root proyek.*

---

## 🚀 Panduan Memulai

### **1. Prasyarat Sistem**
Pastikan perangkat Anda telah terpasang:
- **Flutter SDK** (versi 3.x)
- **Dart SDK**
- **Node.js** (untuk menjalankan skrip pengujian database)

---

### **2. Setup Database & Migrasi**

Sebelum menjalankan aplikasi, pastikan skema basis data di Supabase sudah siap. 

1. Pasang dependensi Node.js di root direktori:
   ```bash
   npm install
   ```
2. Jalankan pengujian konektivitas database untuk mendeteksi jalur koneksi terbaik (Port 5432/6543, direct/pooler):
   ```bash
   node test_all_db_conns.js
   ```
3. Jalankan migrasi basis data untuk menambahkan struktur tabel baru (seperti insentif guru, setelan spanduk, dll.):
   ```bash
   node run_migration.js
   ```
   *Catatan: Skrip ini akan mengeksekusi perintah SQL DDL untuk memperbarui tabel yang ada di Supabase secara aman.*

---

### **3. Menjalankan Aplikasi Flutter**

1. Masuk ke direktori aplikasi Flutter:
   ```bash
   cd gmq_absensi
   ```
2. Unduh dependensi Flutter:
   ```bash
   flutter pub get
   ```
3. Jalankan aplikasi pada perangkat emulator, fisik, atau browser:
   ```bash
   flutter run
   ```

---

### **4. Membuat Build Produksi**

#### **Android (Release APK)**
Untuk membuat file instalasi APK Android:
1. Konfigurasikan metadata rilis di `gmq_absensi/android/gradle.properties`:
   ```properties
   releaseMetadata=yyyymmdd_xx
   ```
2. Jalankan perintah kompilasi:
   ```bash
   cd gmq_absensi
   flutter build apk --release
   ```
Hasil file `.apk` akan tersimpan di: `gmq_absensi/build/app/outputs/flutter-apk/gmq_super_app_[metadata].apk` (misal: `gmq_super_app_20260729_00.apk`).

#### **Flutter Web (Pengujian Lokal)**

Untuk menguji aplikasi versi Web di komputer lokal, Anda dapat menggunakan salah satu dari metode berikut:

##### **Cara 1: Mode Pengembangan (Live Reload/Debugging)**
Metode ini paling cocok saat Anda sedang menulis kode dan membutuhkan fitur *hot reload* / *hot restart*.
```bash
cd gmq_absensi
flutter run -d chrome
```

##### **Cara 2: Build Release & Menggunakan Local Web Server**
Metode ini cocok untuk menguji performa build release yang sesungguhnya di browser.

1. Lakukan kompilasi web ke versi release:
   ```bash
   cd gmq_absensi
   flutter build web --release
   ```
2. Jalankan server lokal dari folder hasil build (`build/web`):
   * **Menggunakan Python (jika terpasang)**:
     ```bash
     cd build/web
     python -m http.server 8080
     ```
     Lalu buka [http://localhost:8080](http://localhost:8080) di browser Anda.
   * **Menggunakan Node.js (npx http-server)**:
     ```bash
     cd build/web
     npx http-server -p 8080
     ```
     Lalu buka [http://localhost:8080](http://localhost:8080) di browser Anda.

##### **Cara 3: Menggunakan Firebase Hosting Emulator**
Metode ini paling disarankan untuk mensimulasikan lingkungan hosting Firebase yang sebenarnya sebelum melakukan penggabungan (*merge*) ke cabang `main`.

1. Lakukan kompilasi web ke versi release:
   ```bash
   cd gmq_absensi
   flutter build web --release
   ```
2. Jalankan Firebase Emulator khusus untuk hosting:
   ```bash
   npx firebase emulators:start --only hosting
   # Atau jika firebase-tools terpasang global:
   firebase emulators:start --only hosting
   ```
3. Buka URL lokal yang diberikan oleh Firebase Emulator (biasanya [http://localhost:5000](http://localhost:5000)) untuk menguji aplikasi Anda.

---

## 🛠️ Aturan Pengembangan & Penerapan (CI/CD)

1. **Uji Coba Lokal**: Selalu jalankan kompilasi dan uji coba fitur secara lokal sebelum melakukan commit.
2. **Tanpa Deploy Manual**: Jangan menjalankan perintah firebase deploy (`npx firebase deploy`) langsung dari komputer lokal Anda.
3. **Penerapan via GitHub**:
   - Push perubahan kode yang sudah teruji ke cabang `main` di repositori GitHub.
   - Pemicu GitHub Actions (`.github/workflows/firebase-hosting-merge.yml`) akan secara otomatis melakukan kompilasi web (`flutter build web`) dan merilis versi terbaru ke Firebase Hosting (**[gmq-absensi.web.app](https://gmq-absensi.web.app)**).
4. **Konfigurasi GitHub Secrets**:
   - Pastikan credential rahasia berikut sudah terkonfigurasi di GitHub Settings -> Secrets and variables -> Actions:
     - `FIREBASE_SERVICE_ACCOUNT_GMQ_ABSENSI`: Kunci token Service Account JSON Firebase untuk deployment otomatis.

---

*Dikembangkan untuk Yayasan Gerakan Memakmurkan Masjid & Quran (YGMQ).*
