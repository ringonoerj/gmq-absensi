# Alur Bisnis Berdasarkan Peran (Role Workflow) - GMQ Absensi V2

Dokumen ini menjelaskan alur bisnis langkah demi langkah yang dialami dan dilakukan oleh masing-masing peran pengguna (*role*) di dalam aplikasi **GMQ Absensi V2** (GMQ Super App).

---

## 1. Alur Kerja Peran: Superadmin

Superadmin bertanggung jawab atas pengelolaan seluruh data master, konfigurasi keuangan (insentif), kalender libur, serta pemeliharaan sistem (backup/restore).

```mermaid
flowchart TD
    Start([Superadmin Login]) --> Dashboard[Dashboard Superadmin]
    
    %% Cabang Master Data
    Dashboard --> MasterData[1. Manajemen Data Master]
    MasterData --> CRUDUnit[CRUD Unit Pendidikan]
    MasterData --> CRUDKelas[CRUD Kelas per Unit]
    MasterData --> CRUDGuru[CRUD Guru & Setting Multi-Unit/Kelas]
    MasterData --> CRUDSiswa[CRUD Siswa & Nama Wali]
    MasterData --> CRUDUsers[CRUD Akun Operator/Supervisor]
    
    %% Cabang Pengaturan Sistem
    Dashboard --> Settings[2. Pengaturan Sistem]
    Settings --> SetHoliday[Config Hari Libur Nasional / Unit]
    Settings --> SetBanner[Config Spanduk Pengumuman Sistem]
    Settings --> BulkUpload[Bulk Upload Data Guru/Siswa via Excel]
    
    %% Cabang Insentif & Keuangan
    Dashboard --> Financial[3. Config Finansial]
    Financial --> SetIncentive[Set Tarif Insentif Guru per Unit]
    
    %% Cabang Backup/Restore
    Dashboard --> SystemMaintenance[4. Pemeliharaan Database]
    SystemMaintenance --> BackupDB[Ekspor Backup SQL]
    SystemMaintenance --> RestoreDB[Impor Restore SQL]
    BackupDB --> LogBackup[Catat Log di backup_logs]
    RestoreDB --> LogBackup
```

### Langkah Operasional Superadmin:
1.  **Pengelolaan Data Master (CRUD)**:
    *   Mendaftarkan unit pendidikan baru (misalnya SD, SMP, SMA, Pondok).
    *   Membuat kelas di masing-masing unit.
    *   Memasukkan profil guru. Jika guru mengajar di lebih dari satu unit atau kelas, admin memilih unit/kelas terkait yang akan disimpan sebagai array ID (`unit_ids` dan `kelas_ids`).
    *   Memasukkan profil siswa beserta nama orang tua/wali untuk koordinasi.
    *   Membuat akun pengguna (`users`) untuk operator unit atau supervisor yayasan.
2.  **Konfigurasi Tarif Insentif**:
    *   Memilih guru $\rightarrow$ Memilih Unit Pendidikan $\rightarrow$ Menginputkan nominal insentif harian (misal: Rp50.000). Data ini disimpan ke tabel `insentif_guru`.
3.  **Pengelolaan Kalender Libur**:
    *   Menambahkan hari libur (misalnya libur nasional atau libur khusus unit pondok). Absensi akan terkunci secara otomatis pada tanggal-tanggal tersebut.
4.  **Operasional Pemeliharaan**:
    *   Melakukan backup database secara berkala atau mengunggah data guru/siswa secara massal (*bulk upload*) menggunakan template Excel untuk menghemat waktu input.

---

## 2. Alur Kerja Peran: Operator

Operator bertugas melakukan pencatatan absensi harian secara langsung di sekolah/unit masing-masing, baik dalam kondisi online maupun offline.

```mermaid
flowchart TD
    Start([Operator Login]) --> Dashboard[Dashboard Operator]
    
    %% Cek Sinkronisasi
    Dashboard --> CekAntrean{Ada Antrean Offline?}
    CekAntrean -->|Ya & Internet Aktif| AutoSync[Sinkronisasi Otomatis Ke Supabase]
    CekAntrean -->|Ya & Internet Mati| ShowIndicator[Tampilkan Indikator Sync Problem]
    CekAntrean -->|Tidak| InputAbsen[Input Absen Baru]
    
    %% Input Absen
    InputAbsen --> FormAbsen[Form Input Absensi]
    FormAbsen --> SelectUnit[1. Pilih Unit Pendidikan]
    SelectUnit --> SelectKelas[2. Pilih Kelas jika Siswa]
    SelectKelas --> SelectType[3. Pilih Tipe: Guru / Siswa]
    SelectType --> SelectName[4. Pilih Nama Subjek]
    SelectName --> SelectDate[5. Pilih Satu/Beberapa Tanggal]
    
    SelectDate --> CheckHoliday{Apakah Tanggal Libur?}
    CheckHoliday -->|Ya| BlockInput[Tampilkan Peringatan Libur & Blokir Simpan]
    CheckHoliday -->|Tidak| SelectStatus[6. Pilih Status Kehadiran]
    
    SelectStatus -->|Hadir / Alpha| SaveProcess[7. Proses Simpan]
    SelectStatus -->|Izin / Sakit| FillReason[Masukkan Alasan Izin/Sakit] --> SaveProcess
    
    %% Proses Simpan
    SaveProcess --> CheckNet{Ada Koneksi Internet?}
    CheckNet -->|Ya| SaveCloud[Kirim ke Supabase]
    SaveCloud --> SuccessOnline[Tampilkan Notifikasi Sukses]
    CheckNet -->|Tidak| SaveLocal[Simpan ke Antrean Hive]
    SaveLocal --> SuccessOffline[Tampilkan Banner: Tersimpan Offline]
```

### Langkah Operasional Operator:
1.  **Pemeriksaan Koneksi & Antrean**:
    *   Buka dasbor. Jika terdapat ikon `sync_problem` berwarna oranye dengan angka, itu menunjukkan adanya data absensi yang belum terkirim ke server karena sebelumnya offline.
    *   Jika internet sudah stabil, tekan tombol **Sync** (ikon putar) untuk mengirimkan data ke database cloud.
2.  **Melakukan Pencatatan Absensi (Harian / Rapel)**:
    *   Masuk ke menu **Input Absen**.
    *   Pilih unit pendidikan yang sedang dioperasikan.
    *   Tentukan subjek absensi (Guru atau Siswa). Jika Siswa, pilih kelasnya terlebih dahulu.
    *   Pilih nama guru atau siswa yang bersangkutan.
    *   Pilih tanggal absensi. Operator dapat memilih lebih dari satu tanggal sekaligus jika ingin merapel absensi yang terlewat.
    *   Tentukan status:
        *   **Hadir**: Langsung disimpan.
        *   **Izin / Sakit**: Masukkan detail alasan (misal: "Sakit Demam" atau "Acara Keluarga").
        *   **Alpha**: Ketidakhadiran tanpa keterangan.
3.  **Melihat Laporan Harian/Bulanan**:
    *   Mengecek statistik kehadiran hari ini pada grafik lingkaran dasbor.
    *   Masuk ke menu **Laporan Absensi** atau **Laporan Insentif Guru** untuk memantau data yang sudah diinput atau mengekspornya ke Excel.

---

## 3. Alur Kerja Peran: Supervisor

Supervisor (biasanya jajaran pengurus yayasan/kepala sekolah) memiliki peran pengawasan. Mereka memantau tren kehadiran dan mengunduh rekapitulasi data keuangan insentif guru untuk pencairan dana.

```mermaid
flowchart TD
    Start([Supervisor Login]) --> Dashboard[Dashboard Supervisor]
    
    %% Pemantauan Grafik
    Dashboard --> ViewDashboard[1. Monitoring Tren Kehadiran]
    ViewDashboard --> ViewStats[Lihat Grafik Lingkaran Persentase Hadir/Izin/Sakit/Alpha]
    ViewDashboard --> ViewHierarchy[Lihat Rekap per Unit & per Kelas]
    
    %% Pelaporan & Audit
    Dashboard --> Reports[2. Pelaporan & Audit]
    Reports --> FilterReport[Filter Laporan Bulanan]
    FilterReport --> FilterCriteria[Unit, Kelas, Kategori, Nama, Bulan]
    
    FilterCriteria --> ViewCalendar[Lihat Kalender Kehadiran Per-Individu]
    FilterCriteria --> ViewSummary[Lihat Tabel Summary Seluruh Anggota]
    
    %% Ekspor Dokumen
    ViewCalendar --> ExportDocs[3. Ekspor Data]
    ViewSummary --> ExportDocs
    ExportDocs --> ExportExcel[Unduh Rekap Laporan Absensi .xlsx]
    ExportDocs --> ExportIncentive[Unduh Rekap Laporan Insentif Guru .xlsx]
```

### Langkah Operasional Supervisor:
1.  **Pemantauan Real-time (Monitoring)**:
    *   Membuka dasbor untuk melihat persentase kehadiran hari ini guna memantau kedisiplinan guru dan santri di seluruh unit pendidikan di bawah yayasan YGMQ.
2.  **Analisis Laporan Bulanan**:
    *   Masuk ke menu **Laporan Absensi**.
    *   Melakukan filter berdasarkan bulan dan unit pendidikan tertentu.
    *   Melihat ringkasan (*Summary*) kehadiran semua anggota (Hadir sekian kali, Izin sekian kali, Sakit sekian kali, Alpha sekian kali, Libur sekian kali).
    *   Atau melakukan inspeksi mendalam terhadap satu orang (*Per User*) dengan melihat tampilan kalender bulanan yang berwarna-warni sesuai status kehadiran (Hijau = Hadir, Oranye = Izin, Biru = Sakit, Merah = Alpha).
3.  **Pencairan Insentif Guru (Export Keuangan)**:
    *   Masuk ke menu **Laporan Insentif Guru**.
    *   Memilih bulan berjalan.
    *   Sistem menyajikan daftar guru beserta total kehadiran hadir mereka dan nominal insentif yang harus dibayarkan.
    *   Supervisor menekan tombol **Export** untuk mendapatkan berkas Excel laporan tersebut sebagai dasar pembayaran payroll bulanan oleh bendahara yayasan.
