# Panduan Animora

Ringkasan semua yang bisa dilakukan Animora saat ini. Versi bahasa Inggris: [GUIDE.md](GUIDE.md).

## 1. Pasang dan buka

1. Ambil Animora gratis dari [Creator Store](https://create.roblox.com/store/asset/116677988518638/Animora) (Studio memasangnya otomatis), atau salin `Animora.rbxmx` dari rilis GitHub ke folder plugin Studio (Studio: **Plugins → Plugins Folder**), lalu buka ulang Studio.
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

- **Anim: nama** membuka daftar animasi rig ini: **New**, **Duplicate**, **Rename**, **Delete**, dan **From template** (Idle, Walk, Run, Jump, Wave). Template hanya titik awal untuk dipelajari; tekan Play lalu sesuaikan posenya.
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

## 9. Kamera (cutscene)

Baris **[ Kamera ]** dan **FOV (zoom)** di bagian atas timeline menganimasikan kamera bersama rig.

1. Atur kamera Studio ke sudut yang diinginkan, letakkan playhead di waktunya, lalu tekan **Kunci kamera**. Posisi dan FOV kamera dikunci bersamaan.
2. Ketik angka (1-120) di kotak **FOV** (baris ketiga toolbar) lalu tekan Enter untuk mengunci zoom di playhead.
3. Nyalakan **Lihat kamera** untuk melihat lewat kamera animasi saat scrub atau Play. Matikan dulu sebelum mengatur sudut berikutnya.
4. Di viewport, garis ungu menunjukkan lintasan kamera, kamera kecil oranye menandai tiap keyframe (putih saat dipilih), dan titik merah menunjukkan posisi kamera di playhead.

Keyframe kamera bisa diberi easing, digeser, disalin, dan dihapus seperti keyframe lain. Kalau kamera menatap karakter, di antara keyframe kamera bergerak mengitari karakter, bukan memotong lurus.

**Export** juga menulis kamera:

- `ReplicatedStorage > AnimoraCameras > <nama animasi>`: data shot (ModuleScript).
- `ReplicatedStorage > AnimoraCamera`: modul pemutar.

Putar dari LocalScript:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimoraCamera = require(ReplicatedStorage.AnimoraCamera)
local shot = require(ReplicatedStorage.AnimoraCameras.ColdOpen)

local playing = AnimoraCamera.play(shot) -- opsi: origin, speed, restore, onEnded
playing:Wait() -- kamera kembali ke pemain setelah shot selesai
```

Isi `origin = character.HumanoidRootPart.CFrame` supaya shot diputar di sekitar karakter yang berdiri di tempat lain. Mainkan animasi karakter di saat yang sama supaya keduanya sinkron.

## 10. Impor

Tekan **Import**:

- Kalau ada KeyframeSequence yang dipilih di Explorer, langsung diimpor.
- Kalau tidak, muncul menu berisi animasi yang tersimpan di place (`RBX_ANIMSAVES`) dan pilihan memuat lewat asset ID. Animasi jenis curve belum bisa diimpor.

## 11. Shortcut

Tombol **Shortcut** di toolbar menampilkan semua tombol keyboard. Daftar ini juga muncul sendiri saat Animora pertama kali dibuka.

**Langsung bisa dipakai.** Klik viewport sekali supaya fokus pindah ke sana, lalu tekan:

| Tombol | Fungsi |
| --- | --- |
| Space | Putar / jeda |
| Z / C | Frame sebelumnya / berikutnya |
| [ / ] | Keyframe sebelumnya / berikutnya |
| R / T | Mode putar / mode geser (root) |
| M | Cerminkan pose |
| Ctrl+Z / Ctrl+Y | Undo / redo |

**Atur tombol sendiri.** Salin, tempel dan hapus belum punya tombol bawaan, karena Ctrl+C, Ctrl+V dan Delete dipakai Studio untuk seleksinya sendiri. Buka **File → Customize Shortcuts**, ketik "Animora" di kotak pencarian, klik kolom Shortcut pada perintahnya lalu tekan tombol, misalnya Alt+C untuk *Animora: Copy keyframes*, Alt+V untuk *Paste keyframes* dan Alt+D untuk *Delete keyframes*. Perintah lain juga bisa diberi tombol sendiri di sana. Tombol ini berlaku di mana saja di Studio selama panel Animora terbuka, dan tombol yang diatur di sana sekaligus di viewport tetap jalan sekali.

Kalau setiap perintah Animora muncul dua kali di Customize Shortcuts, berarti ada dua salinan plugin yang terpasang (misalnya plugin file lokal dan versi yang dipublikasikan). Hapus salah satunya di **Plugins → Manage Plugins** atau di folder Plugins.

## 12. Kalau ada masalah

| Masalah | Coba ini |
| --- | --- |
| Klik memilih seluruh model | Klik bagian tubuhnya sekali lagi; Animora langsung memilihnya selama panelnya terbuka. |
| "tidak punya joint Motor6D atau AnimationConstraint" | Model itu bukan rig yang bisa digerakkan Animora (misalnya mesh skinned). |
| Panah tidak muncul di mode Geser | Panah hanya muncul di root; tekan T untuk memilihnya. |
| R / T, Space atau tombol lain tidak bereaksi | Klik sekali di viewport supaya fokus pindah ke sana, atau pakai tombol di toolbar. |
| Rig masih berpose setelah Animora ditutup | Buka Animora lalu tutup lagi; pose diam akan dikembalikan. |

Menemukan bug atau butuh fitur? Buka issue di [GitHub](https://github.com/Dofly2003/Animora-/issues).
