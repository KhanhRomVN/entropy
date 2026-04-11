# Danh Sách Biome - Entropy World (Đã cập nhật)

Tài liệu này liệt kê chi tiết các hệ sinh thái (Biome) chính thức trong thế giới của **Entropy**, sau khi đã loại bỏ các vùng lạnh và bờ biển phức tạp.

---

## 1. Vùng Đại Dương & Bờ Biển
| Biome | Gạch nền (sid) | Vật thể (Props) | Điều kiện (Noise) | Mô tả |
| :--- | :--- | :--- | :--- | :--- |
| **Đại dương (Ocean)** | 21 (Salt Water) | - | `Height < -0.4` | Vùng nước mặn sâu bao quanh lục địa. |
| **Bờ biển (Beach)** | 2 (Sand) | - | `-0.4 < Height < -0.32` | Bãi cát vàng bao quanh các đảo và lục địa. |

---

## 2. Ma Trận Khí Hậu (Nóng & Ôn Đới)
| Biome | Gạch nền (sid) | Vật thể (Props) | Điều kiện | Mô tả |
| :--- | :--- | :--- | :--- | :--- |
| **Hoang mạc (Desert)** | 2 (Sand) | Xương rồng (20), Quặng đồng (33) | `Hot` & `Dry` | Vùng khô hạn, nắng nóng, nhiều cát. |
| **Rừng rậm (Jungle)** | 9 (Dark Soil) | Cây cà phê/Rừng nhiệt đới (23) | `Hot` & `Wet` | Độ ẩm cao, tầng thực vật dày đặc. |
| **Đồng cỏ (Plains)** | 1 (Grass) | Bụi cây (6) | `Mid/Cold Temp` & `Mid Moist` | Vùng đất hiền hòa, chiếm diện tích lớn nhất. |
| **Rừng sồi (Oak Forest)** | 1 (Grass) | Cây Sồi (18) | `Mid/Cold Temp` & `Wet` | Rừng cây lá rộng phát triển mạnh. |
| **Savannah** | 1 (Grass) | Bụi cây (6) | `Mid/Cold Temp` & `Dry` | Đồng cỏ khô với thảm thực vật thưa. |

---

## 3. Địa Hình Đặc Biệt (Cellular Noise)
| Biome | Gạch nền (sid) | Vật thể (Props) | Điều kiện (b_val) | Mô tả |
| :--- | :--- | :--- | :--- | :--- |
| **Núi lửa (Volcano)** | 4 (Stone) / 7 (Lava) | Tro bụi (25), Quặng vàng (32) | `b_val > 0.95` | Vùng đá nguy hiểm, nhiều khoáng sản quý. |
| **Rừng Tre (Bamboo)** | 10 (Bamboo Ground)| Cây tre (19) | `b_val < 0.05` | Khu vực đặc thù với mật độ tre dày. |
| **Đầm lầy (Swamp)** | 16 (Swamp Water) | - | `Wet` & `Near River` | Vùng nước đọng, độ ẩm cực cao. |

---

## 4. Hệ Thống Thủy Văn
| Thành phần | Gạch nền (sid) | Điều kiện | Mô tả |
| :--- | :--- | :--- | :--- |
| **Sông ngòi (River)** | 3 (Fresh Water) | `River Noise` | Các dòng chảy nối liền từ vùng cao xuống biển. |

---

## Phụ Lục ID Kỹ Thuật
- **sid (Tile ID)**:
  - `1`: Cỏ (Grass)
  - `2`: Cát (Sand)
  - `3`: Nước ngọt (Fresh Water)
  - `4`: Đá (Stone)
  - `7`: Bazan / Đá đen (Bazan) - Hiện chỉ dùng cho vùng Núi lửa.
  - `9`: Đất rừng xậm (Dark Soil)
  - `10`: Đất rừng tre (Bamboo Ground)
  - `12`: Bùn (Mud)
  - `16`: Nước đầm lầy (Swamp Water)
  - `21`: Nước mặn (Salt Water)
- **prop_id (Vật thể)**:
  - `6`: Bụi cây (Bush)
  - `18`: Cây Sồi (Oak)
  - `19`: Cây Tre (Bamboo)
  - `20`: Xương rồng (Cactus)
  - `23`: Cây cà phê / nhiệt đới
  - `25`: Tro bụi núi lửa (Ash)
  - `32`: Quặng Vàng (Gold)
  - `33`: Quặng Đồng (Copper)
