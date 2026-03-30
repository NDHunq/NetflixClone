# 📖 Hướng dẫn chuyển đổi NetflixClone: Programmatic UIKit → XIB

> **Mục đích:** Hướng dẫn từng bước chi tiết để chuyển đổi toàn bộ giao diện của project NetflixClone từ
> việc viết UI bằng code Swift sang việc dùng file `.xib` (Interface Builder).
> Sau khi hoàn thành, bạn sẽ nắm vững cách làm việc với XIB — kỹ năng cần thiết cho dự án sắp tới.

---

## Mục lục

1. [XIB là gì? Tại sao cần học?](#1-xib-là-gì-tại-sao-cần-học)
2. [Bản đồ project hiện tại](#2-bản-đồ-project-hiện-tại)
3. [Kiến thức nền tảng trước khi bắt đầu](#3-kiến-thức-nền-tảng-trước-khi-bắt-đầu)
4. [BƯỚC 1 — TitleCollectionViewCell (đơn giản nhất)](#4-bước-1--titlecollectionviewcell)
5. [BƯỚC 2 — CollectionViewTableViewCell (UITableViewCell + nested CollectionView)](#5-bước-2--collectionviewtableviewcell)
6. [BƯỚC 3 — HeroHeaderUIView (UIView thông thường)](#6-bước-3--heroheaderuiview)
7. [BƯỚC 4 — HomeViewController (ViewController + XIB)](#7-bước-4--homeviewcontroller)
8. [BƯỚC 5 — Các ViewController còn lại + MainTabBarViewController](#8-bước-5--các-viewcontroller-còn-lại)
9. [Tổng kết kiến thức](#9-tổng-kết-kiến-thức)
10. [Checklist tự kiểm tra](#10-checklist-tự-kiểm-tra)

---

## 1. XIB là gì? Tại sao cần học?

### 1.1 Định nghĩa

**XIB** (phát âm: "nib") là file giao diện của Xcode, cho phép bạn **kéo thả** các thành phần UI
(button, label, image view, ...) thay vì viết code Swift.

- File `.xib` thực chất là file **XML** mà Xcode render ra thành giao diện trực quan.
- Khi build app, file `.xib` được biên dịch thành file `.nib` (binary) nằm trong app bundle.

### 1.2 So sánh 3 cách tạo UI trong iOS

| Tiêu chí | Programmatic (Code) | XIB | Storyboard |
|---|---|---|---|
| Tạo UI bằng | Viết Swift | Kéo thả trong IB | Kéo thả trong IB |
| Phạm vi | 1 view/cell/VC | 1 view/cell/VC | Nhiều VC + navigation |
| Preview | Phải build | Thấy ngay | Thấy ngay |
| Git merge | Dễ | Khó (XML) | Rất khó (XML lớn) |
| Tái sử dụng | Tốt | Tốt | Kém |
| Phù hợp | Component phức tạp | Cell, custom view | Prototype nhanh |

### 1.3 Tại sao dự án thực tế dùng XIB?

- **Dễ onboard**: developer mới nhìn vào XIB là hiểu layout ngay, không cần đọc code.
- **Tách biệt rõ ràng**: UI nằm trong `.xib`, logic nằm trong `.swift`.
- **Ít conflict hơn Storyboard**: mỗi file XIB chỉ chứa 1 view → ít merge conflict.
- **Phổ biến trong doanh nghiệp**: phần lớn dự án enterprise dùng XIB hoặc kết hợp XIB + code.

---

## 2. Bản đồ project hiện tại

```
NetflixClone/
├── AppDelegate.swift              ← Không cần sửa
├── SceneDelegate.swift            ← Không cần sửa
├── MainTabBarViewController.swift ← SỬA nhẹ (cách load VC)
├── Controllers/
│   ├── HomeViewController.swift   ← SỬA + TẠO .xib
│   ├── UpcomingViewController.swift   ← SỬA + TẠO .xib
│   ├── SearchViewController.swift     ← SỬA + TẠO .xib
│   └── DownloadsViewController.swift  ← SỬA + TẠO .xib
├── Views/
│   ├── HeroHeaderUIView.swift             ← SỬA + TẠO .xib
│   ├── CollectionViewTableViewCell.swift  ← SỬA + TẠO .xib
│   └── TitleCollectionViewCell.swift      ← SỬA + TẠO .xib
├── Models/
│   └── Title.swift                ← KHÔNG đổi
├── Managers/
│   └── APICaller.swift            ← KHÔNG đổi
├── Resources/
│   └── Extensions.swift           ← KHÔNG đổi
└── ViewModels/                    ← KHÔNG đổi
```

**Quy tắc bất di bất dịch:** Chỉ sửa **UI layer**. Model, Manager, ViewModel không liên quan đến XIB.

---

## 3. Kiến thức nền tảng trước khi bắt đầu

### 3.1 Vòng đời init — Khác biệt cốt lõi

Đây là điều **quan trọng nhất** cần hiểu:

```
┌──────────────────────────────────────────────────┐
│         PROGRAMMATIC (code hiện tại)             │
│                                                  │
│  init(frame:) hoặc init(style:reuseIdentifier:)  │
│         ↓                                        │
│  addSubview(...)   ← thêm UI vào view            │
│         ↓                                        │
│  layoutSubviews()  ← đặt frame thủ công          │
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│              XIB (sẽ chuyển sang)                 │
│                                                  │
│  init?(coder:)     ← iOS gọi khi load từ XIB     │
│         ↓                                        │
│  awakeFromNib()    ← XIB đã load xong, sẵn sàng  │
│         ↓                                        │
│  Auto Layout       ← constraints trong XIB tự lo  │
└──────────────────────────────────────────────────┘
```

**Giải thích:**
- `init(frame:)` = "Tôi tự tạo view bằng code"
- `init?(coder:)` = "iOS tạo view từ file XIB/Storyboard cho tôi"
- `awakeFromNib()` = "File XIB đã load xong, tất cả IBOutlet đã được kết nối, tôi có thể setup thêm"

### 3.2 IBOutlet và IBAction

```swift
// IBOutlet = kết nối từ XIB tới biến Swift (để đọc/sửa thuộc tính)
@IBOutlet weak var posterImageView: UIImageView!

// IBAction = kết nối từ XIB tới hàm Swift (để xử lý sự kiện)
@IBAction func playButtonTapped(_ sender: UIButton) {
    // xử lý khi button được nhấn
}
```

**Tại sao dùng `weak`?** Vì view cha (superview) đã giữ strong reference tới subview rồi.
Nếu dùng `strong` sẽ tạo retain cycle → memory leak.

**Tại sao dùng `!` (force unwrap)?** Vì ta cam kết rằng view này CHẮC CHẮN tồn tại trong XIB.
Nếu quên kết nối trong XIB → crash khi chạy (đây là lỗi phổ biến nhất!).

### 3.3 UINib — Cách iOS load file XIB

```swift
// Tạo object đại diện cho file XIB
let nib = UINib(nibName: "TenFileXIB", bundle: nil)

// Dùng cho Cell: đăng ký với TableView/CollectionView
tableView.register(nib, forCellReuseIdentifier: "CellID")
collectionView.register(nib, forCellWithReuseIdentifier: "CellID")

// Dùng cho UIView thông thường: load trực tiếp
let view = nib.instantiate(withOwner: nil, options: nil).first as! MyCustomView
```

**Lưu ý:** `nibName` phải KHỚP CHÍNH XÁC với tên file `.xib` (không có đuôi `.xib`).

### 3.4 File's Owner vs Custom Class — Dễ nhầm lẫn!

Khi thiết kế XIB, có 2 chỗ để set class:

| | File's Owner | Root View / Cell |
|---|---|---|
| Dùng cho | ViewController | Cell, UIView |
| Ở đâu | Placeholder bên trái | Object trên canvas |
| Kết nối outlet | Ctrl+kéo từ File's Owner | Ctrl+kéo từ root view |

**Quy tắc:**
- **Cell** (UITableViewCell, UICollectionViewCell): set class trên **root cell object**
- **UIView thông thường**: set class trên **File's Owner** (phức tạp hơn, sẽ giải thích ở bước 3)
- **UIViewController**: set class trên **File's Owner**

### 3.5 Auto Layout cơ bản trong Interface Builder

Thay vì viết code `frame = view.bounds`, trong XIB ta dùng **constraints**:

- **Pin constraints** (nút 📌 ở góc dưới phải): Top, Bottom, Leading, Trailing
- **Size constraints**: Width, Height
- **Alignment**: Center X, Center Y

**Ví dụ:** Muốn ImageView chiếm toàn bộ cell → gắn 4 constraints:
`Top=0, Bottom=0, Leading=0, Trailing=0` (tức khoảng cách 4 cạnh đều = 0)

---

## 4. BƯỚC 1 — TitleCollectionViewCell

> **Mục tiêu:** Học cách tạo XIB cho UICollectionViewCell và kết nối IBOutlet.
> Đây là file đơn giản nhất — chỉ có 1 ImageView.

### 4.1. Code hiện tại — Phân tích từng dòng

```swift
class TitleCollectionViewCell: UICollectionViewCell {
    static let identifier = "TitleCollectionViewCell"
    
    // ❌ SẼ XÓA: Tạo ImageView bằng code (closure pattern)
    private let posterImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill  // sẽ set trong XIB
        return imageView
    }()
    
    // ❌ SẼ XÓA: init dành cho programmatic
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(posterImageView)  // sẽ kéo thả trong XIB
    }
    
    // ❌ SẼ XÓA: hiện tại crash nếu load từ XIB
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    // ❌ SẼ XÓA: Auto Layout trong XIB thay thế
    override func layoutSubviews() {
        super.layoutSubviews()
        posterImageView.frame = contentView.bounds
    }
    
    // ✅ GIỮ NGUYÊN logic, chỉ sửa nếu cần
    public func configure(with model: String) {
        guard let url = URL(string: "https://image.tmdb.org/t/p/w500/\(model)") else { return }
        posterImageView.sd_setImage(with: url, completed: nil)
    }
}
```

### 4.2. Tạo file XIB — Từng bước trong Xcode

**Bước A: Tạo file**
1. Click phải vào folder `Views` trong Project Navigator (bên trái Xcode)
2. Chọn **New File...**
3. Ở tab **User Interface**, chọn **"Empty"** → Next
4. Đặt tên: `TitleCollectionViewCell` → Create
5. Đảm bảo file nằm trong group `Views` và target `NetflixClone` được tick

**Bước B: Thêm Collection View Cell vào canvas**
1. Mở file `TitleCollectionViewCell.xib`
2. Mở **Object Library**: nhấn nút `+` ở góc trên phải (hoặc `Cmd + Shift + L`)
3. Tìm `Collection View Cell` → **kéo vào canvas**
4. Xóa View mặc định nếu có (chọn View → nhấn Delete)

**Bước C: Set Custom Class**
1. Chọn **Collection View Cell** trên canvas
2. Mở **Identity Inspector** (icon thứ 3 ở panel phải, hoặc `Cmd + Option + 3`)
3. Ở mục **Custom Class → Class**: gõ `TitleCollectionViewCell`
4. Nhấn Enter → Xcode sẽ tự nhận module

**Bước D: Thêm ImageView và gắn Constraints**
1. Mở Object Library (`Cmd + Shift + L`)
2. Tìm `Image View` → kéo vào trong Cell
3. Chọn ImageView → nhấn nút **Add New Constraints** (icon 📌 ở góc dưới phải canvas)
4. Điền: Top=0, Bottom=0, Leading=0, Trailing=0
5. ✅ Tick "Constrain to margins" OFF (bỏ tick)
6. Nhấn **Add 4 Constraints**
7. Trong **Attributes Inspector**: Content Mode = **Aspect Fill**, tick **Clip to Bounds**

**Bước E: Tạo IBOutlet**
1. Mở **Assistant Editor**: nhấn nút 2 vòng tròn đan nhau ở toolbar (hoặc `Ctrl + Option + Cmd + Enter`)
2. Đảm bảo file `TitleCollectionViewCell.swift` hiển thị bên phải
3. **Ctrl + kéo** từ ImageView trên canvas vào file Swift
4. Trong popup:
   - Connection: **Outlet**
   - Name: `posterImageView`
   - Type: UIImageView
   - Storage: Weak
5. Nhấn **Connect**

### 4.3. Code Swift sau khi sửa

```swift
import UIKit
import SDWebImage

class TitleCollectionViewCell: UICollectionViewCell {
    static let identifier = "TitleCollectionViewCell"
    
    // ✅ MỚI: IBOutlet kết nối với ImageView trong XIB
    @IBOutlet weak var posterImageView: UIImageView!
    
    // ✅ MỚI: Được gọi sau khi XIB load xong
    override func awakeFromNib() {
        super.awakeFromNib()
        // Những config không làm được trong XIB thì làm ở đây
        posterImageView.clipsToBounds = true
    }
    
    // ✅ GIỮ NGUYÊN: Logic không đổi
    public func configure(with model: String) {
        guard let url = URL(string: "https://image.tmdb.org/t/p/w500/\(model)") else { return }
        posterImageView.sd_setImage(with: url, completed: nil)
    }
}
```

**Những gì đã XÓA và TẠI SAO:**

| Code bị xóa | Lý do |
|---|---|
| `private let posterImageView: UIImageView = { ... }()` | XIB tạo ImageView, chỉ cần `@IBOutlet` |
| `override init(frame: CGRect)` | XIB dùng `init?(coder:)` tự động, không cần override |
| `required init?(coder:) { fatalError() }` | XIB CẦN `init?(coder:)` hoạt động, `fatalError()` sẽ crash! |
| `override func layoutSubviews()` | Constraints trong XIB tự quản lý layout |

### 4.4. Sửa nơi đăng ký cell: `CollectionViewTableViewCell.swift`

Tìm dòng register trong file `CollectionViewTableViewCell.swift`:

```swift
// ❌ TRƯỚC: đăng ký bằng class
collectionView.register(TitleCollectionViewCell.self, 
                        forCellWithReuseIdentifier: TitleCollectionViewCell.identifier)

// ✅ SAU: đăng ký bằng UINib
let nib = UINib(nibName: "TitleCollectionViewCell", bundle: nil)
collectionView.register(nib, forCellWithReuseIdentifier: TitleCollectionViewCell.identifier)
```

**Tại sao phải đổi?**
- `register(ClassName.self)` nói iOS "tạo cell bằng `init(frame:)`"
- `register(UINib(...))` nói iOS "tạo cell bằng cách load file XIB, gọi `init?(coder:)`"

### 4.5. Build & Run để kiểm tra

1. `Cmd + B` để build → phải không có lỗi
2. `Cmd + R` để chạy → poster ảnh phim phải hiển thị bình thường
3. Nếu crash → kiểm tra:
   - Tên nibName có khớp với tên file `.xib` không?
   - IBOutlet có kết nối trong XIB không? (mở XIB → click phải vào cell → xem connections)
   - Custom Class có set đúng không?

---

## 5. BƯỚC 2 — CollectionViewTableViewCell

> **Mục tiêu:** Học cách tạo XIB cho UITableViewCell, và xử lý trường hợp cell chứa
> CollectionView bên trong (nested view).

### 5.1. Code hiện tại — Phân tích

```swift
class CollectionViewTableViewCell: UITableViewCell {
    static let indentifier = "CollectionViewTableViewCell"
    private var titles: [Title] = []
    
    // ❌ SẼ XÓA: Tạo CollectionView bằng code
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 140, height: 200)
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(TitleCollectionViewCell.self, 
                                forCellWithReuseIdentifier: TitleCollectionViewCell.identifier)
        return collectionView
    }()
    
    // ❌ SẼ XÓA: init programmatic
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = .systemPink
        contentView.addSubview(collectionView)
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    // ❌ SẼ XÓA
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    // ❌ SẼ XÓA: Auto Layout thay thế
    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = contentView.bounds
    }
    
    // ✅ GIỮ NGUYÊN
    public func configure(with titles: [Title]) { ... }
}
```

### 5.2. Tạo file XIB

**Bước A:** Click phải folder `Views` → New File → User Interface → **Empty** → tên `CollectionViewTableViewCell`

**Bước B:** Mở file XIB mới tạo
1. Mở Object Library (`Cmd + Shift + L`)
2. Tìm **"Table View Cell"** → kéo vào canvas
3. Chọn cell → Identity Inspector → Class: `CollectionViewTableViewCell`

**Bước C:** Thêm Collection View vào trong cell
1. Object Library → tìm **"Collection View"** → kéo vào trong cell
2. Gắn constraints: Top=0, Bottom=0, Leading=0, Trailing=0 (bỏ tick Constrain to margins)
3. Trong Attributes Inspector của Collection View:
   - Scroll Direction: **Horizontal** ← quan trọng!
   - Background: **Default** (hoặc Clear)

**Bước D:** Tạo IBOutlet
1. Mở Assistant Editor
2. Ctrl + kéo Collection View → file Swift
3. Name: `collectionView`, Type: UICollectionView

### 5.3. Code Swift sau khi sửa

```swift
import UIKit

class CollectionViewTableViewCell: UITableViewCell {
    static let indentifier = "CollectionViewTableViewCell"
    private var titles: [Title] = []
    
    // ✅ MỚI: IBOutlet thay vì tạo bằng code
    @IBOutlet weak var collectionView: UICollectionView!
    
    // ✅ MỚI: awakeFromNib thay vì init
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Layout phải set bằng code vì XIB Collection View dùng default layout
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 140, height: 200)
        layout.scrollDirection = .horizontal
        collectionView.collectionViewLayout = layout
        
        // Đăng ký cell con bằng UINib (vì TitleCollectionViewCell cũng dùng XIB rồi)
        let nib = UINib(nibName: "TitleCollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: TitleCollectionViewCell.identifier)
        
        // Set delegate & dataSource
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    // ✅ GIỮ NGUYÊN
    public func configure(with titles: [Title]) {
        self.titles = titles
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    }
}

// ✅ Extension GIỮ NGUYÊN — không đổi gì
extension CollectionViewTableViewCell: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return titles.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleCollectionViewCell.identifier, for: indexPath) as! TitleCollectionViewCell
        if let model = titles[indexPath.row].poster_path {
            cell.configure(with: model)
        }
        return cell
    }
}
```

### 5.4. Lưu ý quan trọng

**Q: Tại sao `UICollectionViewFlowLayout` vẫn phải set bằng code?**
A: XIB cho Collection View mặc định tạo `UICollectionViewFlowLayout` với scroll direction = vertical.
Bạn CÓ THỂ set scroll direction trong XIB (Attributes Inspector), nhưng `itemSize` phải set bằng code
hoặc implement delegate method `sizeForItemAt`. Cách đơn giản nhất là set layout trong `awakeFromNib()`.

**Q: Tại sao không dùng XIB Collection View Cell trong XIB cha?**
A: Collection View trong XIB không hỗ trợ kéo prototype cell trực tiếp như Storyboard.
Phải đăng ký cell bằng code (`register(UINib(...))`).

---

## 6. BƯỚC 3 — HeroHeaderUIView

> **Mục tiêu:** Học cách tạo XIB cho UIView thông thường (KHÔNG phải cell).
> Đây là pattern **khó nhất** vì UIView thông thường không có cơ chế register sẵn.

### 6.1. Code hiện tại — Phân tích

```swift
class HeroHeaderUIView: UIView {
    
    // ❌ SẼ THÀNH IBOutlet
    private let heroImageView: UIImageView = { ... }()
    private let playButton = { ... }()
    private let downloadButton = { ... }()
    
    // ❌ SẼ XÓA
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(heroImageView)
        addGradient()
        addSubview(playButton)
        addSubview(downloadButton)
        applyConstraints()  // ← constraints viết bằng code
    }
    
    // ❌ SẼ XÓA
    private func applyConstraints() { ... }  // ← XIB thay thế
    
    // ✅ GIỮ: gradient không thể tạo trong XIB
    private func addGradient() { ... }
    
    // ❌ SẼ XÓA
    override func layoutSubviews() { ... }
    
    // ❌ SẼ XÓA
    required init?(coder: NSCoder) { fatalError() }
}
```

### 6.2. Có 2 cách load UIView từ XIB — Hiểu rõ sự khác biệt

#### Cách 1: Load trực tiếp (đơn giản, phù hợp cho trường hợp này)

```swift
// Nơi sử dụng (ví dụ: HomeViewController):
let headerView = UINib(nibName: "HeroHeaderUIView", bundle: nil)
    .instantiate(withOwner: nil, options: nil).first as! HeroHeaderUIView
headerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 450)
```

**Trong XIB:** Set **Custom Class trên root view** = `HeroHeaderUIView`

#### Cách 2: Load qua File's Owner (phức tạp hơn, dùng khi muốn embed XIB vào code hoặc Storyboard)

```swift
// Trong class:
required init?(coder: NSCoder) {
    super.init(coder: coder)
    loadNib()
}

override init(frame: CGRect) {
    super.init(frame: frame)
    loadNib()
}

private func loadNib() {
    let nib = UINib(nibName: "HeroHeaderUIView", bundle: nil)
    guard let contentView = nib.instantiate(withOwner: self, options: nil).first as? UIView else { return }
    contentView.frame = bounds
    contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(contentView)
}
```

**Trong XIB:** Set **File's Owner** = `HeroHeaderUIView`, root view KHÔNG set class.

> **Cho project này:** Dùng **Cách 1** vì đơn giản hơn và HeroHeaderUIView chỉ dùng ở 1 chỗ.

### 6.3. Tạo file XIB

**Bước A:** Click phải folder `Views` → New File → User Interface → **Empty** → tên `HeroHeaderUIView`

**Bước B:** Thiết kế trong XIB
1. Chọn root View trên canvas
2. **Identity Inspector** → Class: `HeroHeaderUIView`
3. **Size Inspector** (icon thước kẻ): Height = 450 (để preview đúng kích thước)

**Bước C:** Thêm UI elements

1. **ImageView** (hero background):
   - Kéo UIImageView vào view
   - Constraints: Top=0, Bottom=0, Leading=0, Trailing=0
   - Attributes: Content Mode = **Aspect Fill**, ✅ Clip to Bounds
   - Image: chọn `dune` (nếu có trong Assets)

2. **Play Button**:
   - Kéo UIButton vào view
   - Constraints:
     - Leading = 70 (so với superview)
     - Bottom = 50 (so với superview)
     - Width = 110
   - Attributes: Title = "Play", Style = Default
   - Tự set border bằng code (không thể set trong XIB)

3. **Download Button**:
   - Kéo UIButton vào view
   - Constraints:
     - Trailing = 70 (so với superview)
     - Bottom = 50 (so với superview)
     - Width = 110
   - Attributes: Title = "Download"

**Bước D:** Tạo IBOutlets (Ctrl + kéo từ mỗi element sang file Swift)
- `heroImageView: UIImageView`
- `playButton: UIButton`
- `downloadButton: UIButton`

### 6.4. Code Swift sau khi sửa

```swift
import UIKit

class HeroHeaderUIView: UIView {
    
    // ✅ MỚI: IBOutlets thay vì tạo bằng code
    @IBOutlet weak var heroImageView: UIImageView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var downloadButton: UIButton!
    
    // ✅ MỚI: awakeFromNib thay vì init(frame:)
    override func awakeFromNib() {
        super.awakeFromNib()
        setupButtons()
        addGradient()
    }
    
    private func setupButtons() {
        // Border không thể set trong XIB → vẫn phải code
        for button in [playButton!, downloadButton!] {
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 5
        }
    }
    
    // ✅ GIỮ NGUYÊN: CAGradientLayer không thể tạo trong XIB
    private func addGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.systemBackground.cgColor
        ]
        gradientLayer.frame = bounds
        layer.addSublayer(gradientLayer)
    }
    
    // ✅ MỚI: Cần override để cập nhật gradient khi size thay đổi
    override func layoutSubviews() {
        super.layoutSubviews()
        // Gradient layer cần update frame khi view resize
        layer.sublayers?.first(where: { $0 is CAGradientLayer })?.frame = bounds
    }
    
    // ✅ MỚI: Helper method để load từ XIB
    static func loadFromNib() -> HeroHeaderUIView {
        let nib = UINib(nibName: "HeroHeaderUIView", bundle: nil)
        return nib.instantiate(withOwner: nil, options: nil).first as! HeroHeaderUIView
    }
}
```

### 6.5. Những gì KHÔNG THỂ làm trong XIB

| Thuộc tính | Trong XIB? | Phải code? |
|---|---|---|
| Content Mode (Aspect Fill) | ✅ Có | Không cần |
| Clip to Bounds | ✅ Có | Không cần |
| Corner Radius | ❌ Không | ✅ Code |
| Border Color & Width | ❌ Không | ✅ Code |
| CAGradientLayer | ❌ Không | ✅ Code |
| Shadow | ❌ Không | ✅ Code |
| Font, Text Color | ✅ Có | Không cần |
| Background Color | ✅ Có | Không cần |
| Constraints | ✅ Có | Không cần |

> **Mẹo:** Có thể dùng **User Defined Runtime Attributes** trong Identity Inspector để set
> `layer.cornerRadius` trong XIB, nhưng `layer.borderColor` cần `CGColor` nên PHẢI code.

---

## 7. BƯỚC 4 — HomeViewController

> **Mục tiêu:** Học cách tạo XIB cho UIViewController.
> ViewController là trường hợp đặc biệt: XIB chỉ chứa view, logic vẫn 100% trong Swift.

### 7.1. Code hiện tại — Phân tích

```swift
class HomeViewController: UIViewController {
    
    // ❌ SẼ THÀNH IBOutlet
    private let homeFeedTable: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.register(CollectionViewTableViewCell.self, 
                       forCellReuseIdentifier: CollectionViewTableViewCell.indentifier)
        return table
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground  // ← set trong XIB
        view.addSubview(homeFeedTable)             // ← XIB tự lo
        homeFeedTable.delegate = self
        homeFeedTable.dataSource = self
        configureNavBar()
        
        let headerView = HeroHeaderUIView(frame: CGRect(...))  // ← đổi sang loadFromNib()
        homeFeedTable.tableHeaderView = headerView
    }
    
    // ❌ SẼ XÓA: Auto Layout thay thế
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        homeFeedTable.frame = view.bounds
    }
}
```

### 7.2. Tạo file XIB

**Bước A:** Click phải folder `Controllers` → New File → User Interface → **Empty** → tên `HomeViewController`

**Bước B:** Set File's Owner (QUAN TRỌNG — khác với Cell!)
1. Chọn **File's Owner** (placeholder ở Document Outline bên trái, KHÔNG phải view trên canvas)
2. Identity Inspector → Class: `HomeViewController`

> ⚠️ **KHÔNG set Custom Class trên root view!** Với ViewController, luôn set trên File's Owner.

**Bước C:** Kết nối root view
1. Ctrl + kéo từ **File's Owner** → **root View** trên canvas
2. Chọn **`view`** trong popup (đây là property `self.view` của UIViewController)
3. Bước này BẮT BUỘC! Nếu không sẽ crash với lỗi "loaded nib but the view outlet was not set"

**Bước D:** Thêm Table View
1. Kéo **Table View** vào root view
2. Constraints: Top=0, Bottom=0, Leading=0, Trailing=0
3. Attributes Inspector:
   - Style: **Grouped** ← quan trọng! Phải khớp với code hiện tại
   - Separator: Default

**Bước E:** Tạo IBOutlet
1. Ctrl + kéo từ Table View → file Swift (qua Assistant Editor)
2. Name: `homeFeedTable`, Type: UITableView

### 7.3. Code Swift sau khi sửa

```swift
import UIKit

enum Sections: Int {
    case TrendingMovies = 0
    case TrendingTV = 1
    case Popular = 2
    case UpcomingMovies = 3
    case TopRated = 4
}

class HomeViewController: UIViewController {
    
    let sectionTiles: [String] = ["Trending Movies", "Trending TV", "Popular", "Upcoming Movies", "Top Rated"]
    
    // ✅ MỚI: IBOutlet thay vì tạo bằng code
    @IBOutlet weak var homeFeedTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Không cần set backgroundColor — đã set trong XIB
        // Không cần addSubview — đã kéo thả trong XIB
        
        // Đăng ký cell bằng UINib
        let cellNib = UINib(nibName: "CollectionViewTableViewCell", bundle: nil)
        homeFeedTable.register(cellNib, forCellReuseIdentifier: CollectionViewTableViewCell.indentifier)
        
        homeFeedTable.delegate = self
        homeFeedTable.dataSource = self
        
        configureNavBar()
        
        // ✅ MỚI: Load header từ XIB
        let headerView = HeroHeaderUIView.loadFromNib()
        headerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 450)
        homeFeedTable.tableHeaderView = headerView
    }
    
    // ✅ XÓA viewDidLayoutSubviews() — Auto Layout trong XIB tự quản lý
    
    private func configureNavBar() {
        // ✅ GIỮ NGUYÊN — navigation bar config vẫn phải code
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "person"), style: .done, target: self, action: nil),
            UIBarButtonItem(image: UIImage(systemName: "play.rectangle"), style: .done, target: self, action: nil)
        ]
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.backgroundColor = .clear
    }
}

// ✅ Extension GIỮ NGUYÊN — delegate/dataSource logic không đổi
extension HomeViewController: UITableViewDelegate, UITableViewDataSource {
    // ... tất cả methods giữ nguyên
}
```

### 7.4. Sửa `MainTabBarViewController.swift` — Cách load VC từ XIB

```swift
class MainTabBarViewController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // ✅ MỚI: Load VC từ XIB bằng nibName
        // Khi tên XIB trùng tên class, có thể dùng nibName: nil
        let vc1 = UINavigationController(
            rootViewController: HomeViewController(nibName: "HomeViewController", bundle: nil)
        )
        let vc2 = UINavigationController(
            rootViewController: UpcomingViewController(nibName: "UpcomingViewController", bundle: nil)
        )
        let vc3 = UINavigationController(
            rootViewController: SearchViewController(nibName: "SearchViewController", bundle: nil)
        )
        let vc4 = UINavigationController(
            rootViewController: DownloadsViewController(nibName: "DownloadsViewController", bundle: nil)
        )
        
        // Phần còn lại giữ nguyên
        vc1.tabBarItem.image = UIImage(systemName: "house")
        vc2.tabBarItem.image = UIImage(systemName: "play.circle")
        vc3.tabBarItem.image = UIImage(systemName: "magnifyingglass")
        vc4.tabBarItem.image = UIImage(systemName: "arrow.down.to.line")
        
        vc1.title = "Home"
        vc2.title = "Coming Soon"
        vc3.title = "Top Search"
        vc4.title = "Downloads"
        
        tabBar.tintColor = .label
        
        setViewControllers([vc1, vc2, vc3, vc4], animated: true)
    }
}
```

---

## 8. BƯỚC 5 — Các ViewController còn lại

> **Mục tiêu:** Tự thực hành với `UpcomingViewController`, `SearchViewController`, `DownloadsViewController`.
> Đây là bài tập để bạn tự áp dụng kiến thức đã học.

### 8.1. Các VC này hiện rất đơn giản

```swift
// Cả 3 VC đều giống nhau:
class UpcomingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}
```

### 8.2. Cách chuyển

Mỗi VC cần:

1. **Tạo file XIB** (cùng tên với class)
2. **Set File's Owner** = tên class
3. **Kết nối `view` outlet**: Ctrl + kéo File's Owner → Root View → chọn `view`
4. **Set background color** trong XIB thay vì code
5. **Xóa** `view.backgroundColor = .systemBackground` trong `viewDidLoad()`

### 8.3. Template code sau khi sửa

```swift
class UpcomingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Background color đã set trong XIB
        // Thêm logic khác ở đây nếu cần
    }
}
```

---

## 9. Tổng kết kiến thức

### 9.1. Bảng so sánh tổng hợp

| Loại View | Tạo XIB bằng | Set Class ở đâu | Đăng ký/Load bằng | Init lifecycle |
|---|---|---|---|---|
| UICollectionViewCell | Empty XIB + kéo Cell | Root Cell | `register(UINib(...))` | `awakeFromNib()` |
| UITableViewCell | Empty XIB + kéo Cell | Root Cell | `register(UINib(...))` | `awakeFromNib()` |
| UIView (custom) | Empty XIB | Root View hoặc File's Owner | `UINib.instantiate(...)` | `awakeFromNib()` |
| UIViewController | Empty XIB | File's Owner | `init(nibName:bundle:)` | `viewDidLoad()` |

### 9.2. Quy trình chuẩn khi tạo XIB cho bất kỳ view nào

```
1. Tạo file .xib (File → New → User Interface → Empty)
2. Kéo đúng loại object vào canvas (Cell, View, ...)
3. Set Custom Class (Identity Inspector)
4. Kéo UI elements và gắn Constraints
5. Tạo IBOutlets (Ctrl + kéo)
6. Sửa file Swift:
   - Xóa code tạo UI
   - Xóa init programmatic
   - Thêm awakeFromNib()
   - Đổi @IBOutlet
7. Sửa nơi sử dụng:
   - Cell: register(UINib(...))
   - UIView: UINib.instantiate(...)
   - VC: init(nibName:bundle:)
8. Build & Run kiểm tra
```

### 9.3. Lỗi thường gặp và cách sửa

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| **Crash: "loaded nib but view outlet not set"** | Chưa kết nối `view` outlet cho VC | Ctrl+kéo File's Owner → View → chọn `view` |
| **Crash: "unexpectedly found nil while unwrapping"** | IBOutlet chưa kết nối trong XIB | Mở XIB → click phải → kiểm tra connections |
| **UI không hiển thị** | Quên set Custom Class | Kiểm tra Identity Inspector |
| **Cell trắng/trống** | Dùng `register(Class.self)` thay vì `register(UINib)` | Đổi sang `register(UINib(...))` |
| **Layout sai** | Constraints thiếu hoặc conflict | Xcode sẽ warning → fix theo gợi ý |
| **"Could not load NIB in bundle"** | Tên nibName không khớp tên file | Kiểm tra tên chính xác (case-sensitive!) |
| **Crash: "init(coder:) fatalError"** | Chưa xóa `fatalError()` trong `init?(coder:)` | Xóa method `required init?(coder:)` hoặc implement đúng |

---

## 10. Checklist tự kiểm tra

### Bước 1: TitleCollectionViewCell
- [ ] Tạo file `TitleCollectionViewCell.xib`
- [ ] Kéo Collection View Cell vào canvas
- [ ] Set Custom Class = `TitleCollectionViewCell`
- [ ] Thêm ImageView + constraints (4 cạnh = 0)
- [ ] Set Content Mode = Aspect Fill, Clip to Bounds
- [ ] Tạo IBOutlet `posterImageView`
- [ ] Sửa Swift: xóa init, layoutSubviews, thêm awakeFromNib
- [ ] Sửa register trong CollectionViewTableViewCell
- [ ] Build & Run OK ✅

### Bước 2: CollectionViewTableViewCell
- [ ] Tạo file `CollectionViewTableViewCell.xib`
- [ ] Kéo Table View Cell vào canvas
- [ ] Set Custom Class = `CollectionViewTableViewCell`
- [ ] Thêm Collection View + constraints (4 cạnh = 0)
- [ ] Set Scroll Direction = Horizontal
- [ ] Tạo IBOutlet `collectionView`
- [ ] Sửa Swift: xóa init, layoutSubviews, thêm awakeFromNib
- [ ] Setup layout + register cell trong awakeFromNib
- [ ] Build & Run OK ✅

### Bước 3: HeroHeaderUIView
- [ ] Tạo file `HeroHeaderUIView.xib`
- [ ] Set Custom Class trên root view = `HeroHeaderUIView`
- [ ] Thêm ImageView + constraints (4 cạnh = 0)
- [ ] Thêm Play Button + constraints
- [ ] Thêm Download Button + constraints
- [ ] Tạo 3 IBOutlets
- [ ] Sửa Swift: thêm awakeFromNib, loadFromNib(), giữ gradient code
- [ ] Build & Run OK ✅

### Bước 4: HomeViewController
- [ ] Tạo file `HomeViewController.xib`
- [ ] Set **File's Owner** = `HomeViewController`
- [ ] Kết nối view outlet
- [ ] Thêm Table View (style Grouped) + constraints
- [ ] Tạo IBOutlet `homeFeedTable`
- [ ] Sửa Swift: xóa tạo table bằng code, xóa viewDidLayoutSubviews
- [ ] Đổi register sang UINib, đổi HeroHeader sang loadFromNib
- [ ] Sửa MainTabBarViewController: dùng init(nibName:)
- [ ] Build & Run OK ✅

### Bước 5: Các VC còn lại
- [ ] Tạo XIB cho UpcomingViewController
- [ ] Tạo XIB cho SearchViewController
- [ ] Tạo XIB cho DownloadsViewController
- [ ] Build & Run toàn bộ OK ✅

---

> **Lời khuyên cuối:** Hãy làm **từng bước một**, build và run sau mỗi bước.
> Đừng sửa tất cả cùng lúc — nếu crash bạn sẽ không biết lỗi ở đâu.
> Mỗi bước thành công là một kiến thức mới bạn đã nắm vững! 🚀
