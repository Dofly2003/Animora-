# Panduan Animora

Ringkasan semua yang bisa dilakukan Animora saat ini. Versi bahasa Inggris: [GUIDE.md](GUIDE.md).

## 1. Pasang dan buka

1. Ambil Animora dari Creator Store, atau salin `Animora.rbxmx` dari rilis GitHub ke folder plugin Studio (Studio: **Plugins → Plugins Folder**), lalu buka ulang Studio.
2. Klik **Animora** di tab **Plugins**. Editor terbuka sebagai panel di bagian bawah Studio.
3. Pilih bahasa dengan tombol **EN / ID** (kanan atas panel).

## 2. Pilih rig

- Klik bagian tubuh karakter mana saja di viewport. Animora memilih rig itu beserta sendi bagian yang diklik.
- Klik menembus rambut, baju, dan aksesori lain, dan klik yang sedikit meleset di samping tangan atau kaki tetap dihitung.
- Baris status (baris ketiga) menampilkan nama rig, tipenya (**R15**, **R6**, **Rig kustom**, ditambah **Constraint** untuk avatar Avatar Joint Upgrade), dan sendi yang dipilih.
- Sendi juga bisa dipilih dengan mengklik barisnya di timeline.

Yang didukung: R6, R15, rig Motor6D buatan sendiri, dan avatar AnimationConstraint. Mesh skinned (bone) belum didukung.

## 3. Membuat pose

Ada dua mode gizmo. Ganti dengan tombol di toolbar, atau tekan **R** dan **T** saat kursor ada di viewport.

| Mode | Fungsi |
| --- | --- |
| **Putar (R)** | Cincin di sekitar bagian yang dipilih. Seret cincin untuk memutar sendi. |
| **Geser (T)** | Panah di root (LowerTorso di R15, Torso di R6). Seret untuk menaikkan, menurunkan, atau menggeser seluruh badan. Geseran dibulatkan per 0,05 stud. Sendi lain selalu menampilkan cincin putar. |

Setiap kali selesai menyeret, keyframe langsung dibuat atau diperbarui di posisi playhead (auto-key). **Ctrl+Z / Ctrl+Y** membatalkan dan mengulanginya, bersama riwayat Studio lainnya.

## 4. Timeline

- **Scrub:** seret di penggaris bagian atas. **Zoom:** roda mouse. **Geser tampilan:** Shift + roda mouse.
- **Melangkah:** `|<` dan `>|` lompat ke keyframe sebelum / sesudahnya, `<` dan `>` maju atau mundur satu frame.
- **Memilih keyframe:** klik penandanya; Shift atau Ctrl + klik untuk menambah pilihan; seret di area kosong untuk memilih dengan kotak.
- **Memindahkan keyframe:** seret penanda yang dipilih ke kiri atau kanan. Posisinya dibulatkan ke frame terdekat.

## 5. Mengedit keyframe

| Tombol | Fungsi |
| --- | --- |
| **Salin** | Menyalin keyframe yang dipilih, atau seluruh pose di playhead kalau tidak ada yang dipilih. |
| **Tempel** | Menempel di posisi playhead. |
| **Hapus** | Menghapus keyframe yang dipilih. |
| **Mirror** | Mencerminkan sendi yang dipilih kiri/kanan, atau seluruh pose kalau tidak ada sendi yang dipilih. |
| **Easing** | Membuka panel easing: pilih keyframe dulu, lalu pilih gaya dan arahnya. Easing mengatur bentuk gerakan menuju keyframe berikutnya. |

## 6. Animasi dan pengaturan klip

Baris pertama toolbar berisi pengaturan klip:

- **Anim: nama** membuka daftar animasi rig ini: **New**, **Duplicate**, **Rename**, **Delete**, dan **From template** (20 template: Idle, Walk, Run, Jump, Wave, set Scared, Flashlight, set hantu, dan set NISKALA). Template hanya titik awal; tekan Play lalu sesuaikan posenya.
- **Durasi** dalam detik (ketik angka lalu tekan Enter).
- **Loop** nyala atau mati.
- **FPS** berganti 24 → 30 → 60. Waktu keyframe tetap dalam detik.
- **Priority** berganti Core → Idle → Movement → Action → Action2 → Action3 → Action4.

Putar atau jeda dengan tombol **Play** di baris kedua.

## 7. Menyimpan

Animora menyimpan otomatis di dalam place, jadi pekerjaanmu ikut tersimpan di file `.rbxl` dan di Team Create:

- `ServerStorage > AnimoraSaves > Rigs > <nama rig>` berisi animasi tiap rig.

Simpan place seperti biasa (Ctrl+S). Saat menekan Run (F8) atau Play untuk mencoba, rig kembali ke pose diam supaya game mulai dalam keadaan bersih.

## 8. Ekspor dan publish

1. Tekan **Export**. Animasi ditulis sebagai KeyframeSequence ke `ServerStorage > RBX_ANIMSAVES > <nama rig>` lalu dipilih.
2. Klik kanan → **Save to Roblox**, atau buka di Animation Editor bawaan Roblox dan publish dari sana.
3. Salin asset ID animasinya dan pakai di game (`rbxassetid://<id>`).

## 9. Impor

Tekan **Import**:

- Kalau ada KeyframeSequence yang dipilih di Explorer, langsung diimpor.
- Kalau tidak, muncul menu berisi animasi yang tersimpan di place (`RBX_ANIMSAVES`) dan pilihan memuat lewat asset ID. Animasi jenis curve belum bisa diimpor.

## 10. Shortcut

Perintah Animora terdaftar sebagai plugin action Studio. Atur tombolnya di **File → Customize Shortcuts** (cari "Animora"): Play / Pause, frame berikut / sebelumnya, keyframe berikut / sebelumnya, Copy, Paste, Delete keyframes, Mirror, Rotate mode, Move mode. **R** dan **T** di viewport langsung bisa dipakai tanpa diatur.

## 11. Kalau ada masalah

| Masalah | Coba ini |
| --- | --- |
| Klik memilih seluruh model | Klik bagian tubuhnya sekali lagi; Animora langsung memilihnya selama panelnya terbuka. |
| "tidak punya joint Motor6D atau AnimationConstraint" | Model itu bukan rig yang bisa digerakkan Animora (misalnya mesh skinned). |
| Panah tidak muncul di mode Geser | Panah hanya muncul di root; tekan T untuk memilihnya. |
| R / T tidak bereaksi | Klik sekali di viewport supaya fokus pindah ke sana, atau pakai tombol di toolbar. |
| Rig masih berpose setelah Animora ditutup | Buka Animora lalu tutup lagi; pose diam akan dikembalikan. |

Menemukan bug atau butuh fitur? Buka issue di [GitHub](https://github.com/Dofly2003/Animora-/issues).
