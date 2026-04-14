# 🎬 Hướng dẫn xây dựng Splash Screen + Login Screen

> **Mục đích:** Hướng dẫn từng bước thêm 2 màn hình mới vào đầu app:
> 1. **Splash Screen** — Animation GIF khi mở app → tự động chuyển sang Login
> 2. **Login Screen** — Giao diện đăng nhập kiểu Netflix (nền poster phim + Email/Password/Sign In)
>
> Pattern sử dụng: **XIB + SDWebImage (GIF) + SceneDelegate routing** — rất phổ biến trong app thương mại.

---

## Mục lục

1. [Tổng quan luồng hoạt động](#1-tổng-quan-luồng-hoạt-động)
2. [Bản đồ file cần tạo / sửa](#2-bản-đồ-file-cần-tạo--sửa)
3. [BƯỚC 1 — Cài đặt SDWebImage (CocoaPods)](#3-bước-1--cài-đặt-sdwebimage-cocoapods)
4. [BƯỚC 2 — Thêm file GIF Animation vào project](#4-bước-2--thêm-file-gif-animation-vào-project)
5. [BƯỚC 3 — Tạo SplashViewController (XIB)](#5-bước-3--tạo-splashviewcontroller-xib)
6. [BƯỚC 4 — Tạo LoginViewController (XIB)](#6-bước-4--tạo-loginviewcontroller-xib)
7. [BƯỚC 5 — Cập nhật SceneDelegate để bắt đầu từ Splash](#7-bước-5--cập-nhật-scenedelegate-để-bắt-đầu-từ-splash)
8. [Tổng kết & Checklist](#8-tổng-kết--checklist)

---

## 1. Tổng quan luồng hoạt động

### 1.1. Luồng màn hình

```
App khởi động
      │
      ▼
┌─────────────────────────────────┐
│       SplashViewController      │
│                                 │
│    [GIF Animation chạy]         │
│    (ví dụ: Netflix N flare)     │
│                                 │
│    Sau 2-3 giây → tự chuyển    │
└──────────────┬──────────────────┘
               │ present fullScreen
               ▼
┌─────────────────────────────────┐
│       LoginViewController       │
│                                 │
│  ┌───────────────────────────┐  │
│  │  [Poster Collage - Top]   │  │  ← UIImageView nền
│  │                           │  │
│  │      N E T F L I X        │  │  ← UILabel đỏ, bold
│  │                           │  │
│  │  ┌─────────────────────┐  │  │
│  │  │       Email         │  │  │  ← UITextField
│  │  └─────────────────────┘  │  │
│  │  ┌─────────────────────┐  │  │
│  │  │      Password       │  │  │  ← UITextField (secure)
│  │  └─────────────────────┘  │  │
│  │  ┌─────────────────────┐  │  │
│  │  │       Sign in       │  │  │  ← UIButton đỏ
│  │  └─────────────────────┘  │  │
│  │                           │  │
│  │  Is it first time? Sign up│  │  ← UILabel + attr. string
│  │    Or sign in with        │  │
│  │   [G]   [f]               │  │  ← 2 UIButton (Google/Facebook)
│  └───────────────────────────┘  │
└─────────────────────────────────┘
               │ Sau khi đăng nhập thành công
               ▼
┌─────────────────────────────────┐
│     MainTabBarViewController    │  ← App chính (đã có)
└─────────────────────────────────┘
```

### 1.2. Tại sao dùng SDWebImage để chạy GIF?

| Cách | Ưu điểm | Nhược điểm |
|---|---|---|
| `UIImage(named:)` thông thường | Không cần thêm pod | ❌ Không chạy GIF — chỉ hiện frame đầu |
| Custom GIF parser thuần Swift | Không phụ thuộc | ❌ Code phức tạp, quản lý frame thủ công |
| **SDWebImage** ✅ | Chạy GIF cực đơn giản, chỉ 2 dòng | Cần thêm pod (nhỏ, nhẹ) |

SDWebImage cung cấp `SDAnimatedImageView` — một subclass của `UIImageView` có thể render GIF một cách mượt mà, tự động quản lý bộ nhớ.

### 1.3. Kiến thức sẽ học được

| Concept | Ở bước nào |
|---|---|
| Cài pod mới (SDWebImage) và `pod install` | Bước 1 |
| Thêm file resource (.gif) vào Xcode | Bước 2 |
| `SDAnimatedImageView` + `SDAnimatedImage` — chạy GIF | Bước 3 |
| `DispatchQueue.main.asyncAfter` — delay tự chuyển màn | Bước 3 |
| Tạo ViewController + XIB | Bước 3, 4 |
| UITextField custom style (border đỏ, bo góc) | Bước 4 |
| UIButton custom style (nền đỏ, bo góc) | Bước 4 |
| NSAttributedString cho text nhiều màu | Bước 4 |
| `SceneDelegate` routing — chọn rootViewController | Bước 5 |

---

## 2. Bản đồ file cần tạo / sửa

```
NetflixClone/
├── Podfile                                    ← [SỬA] Thêm pod 'SDWebImage'
│
├── NetflixClone/
│   ├── Resources/
│   │   └── splash_animation.gif              ← [MỚI] File GIF animation (bạn tự thêm)
│   │
│   ├── Controllers/
│   │   ├── SplashViewController.swift         ← [MỚI] Màn hình splash
│   │   ├── SplashViewController.xib           ← [MỚI] XIB cho splash
│   │   ├── LoginViewController.swift          ← [MỚI] Màn hình đăng nhập
│   │   └── LoginViewController.xib            ← [MỚI] XIB cho login
│   │
│   └── SceneDelegate.swift                    ← [SỬA] Đổi rootVC về SplashViewController
```

**Thứ tự làm:** Podfile → GIF file → SplashVC → LoginVC → SceneDelegate

**Tổng:** 4 file mới + 2 file sửa = 6 file

---

## 3. BƯỚC 1 — Cài đặt SDWebImage (CocoaPods)

> **Mục tiêu:** Thêm thư viện `SDWebImage` để render GIF động trong `SDAnimatedImageView`.

### 3.1. Mở file `Podfile`

File nằm ở thư mục gốc của project (ngang hàng với `.xcworkspace`).

### 3.2. Thêm pod SDWebImage

```ruby
target 'NetflixClone' do
  use_frameworks!

  # Pods đã có
  pod 'GRDB.swift/SQLCipher'
  pod 'SQLCipher', '~> 4.0'
  pod 'Alamofire', '~> 5.0'

  # ✅ MỚI: SDWebImage — load ảnh từ URL và render GIF
  pod 'SDWebImage'
end
```

### 3.3. Chạy pod install

Mở **Terminal**, `cd` vào thư mục gốc project:

```bash
cd /path/to/NetflixClone
pod install
```

Output mong đợi:
```
Installing SDWebImage (x.x.x)
Pod installation complete! There are 4 dependencies from the Podfile and 4 total pods installed.
```

> ⚠️ **Quan trọng:** Sau `pod install`, luôn mở project qua file **`.xcworkspace`**, KHÔNG dùng `.xcodeproj`.

### 3.4. Build kiểm tra

`Cmd + B` — phải thành công, không lỗi.

---

## 4. BƯỚC 2 — Thêm file GIF Animation vào project

> **Mục tiêu:** Thêm file `.gif` vào project để Splash Screen phát.

### 4.1. Chuẩn bị file GIF

Bạn đã có file `.gif` sẵn rồi — đổi tên dễ nhớ, ví dụ: `splash_animation.gif`

> 💡 **Gợi ý tìm GIF chất lượng cao:**
> - [Giphy](https://giphy.com) — tìm "netflix intro", "movie loading"
> - [LottieFiles](https://lottiefiles.com) — một số có export ra GIF
> - Nếu GIF có background trắng, có thể dùng Photoshop/online tool để xóa nền

### 4.2. Thêm vào Xcode

1. Trong Xcode, click phải vào folder **Resources** trong Project Navigator
2. Chọn **Add Files to "NetflixClone"...**
3. Tìm đến file `.gif` của bạn
4. Đảm bảo:
   - ✅ **Copy items if needed**
   - ✅ **Add to targets: NetflixClone**
5. Nhấn **Add**

### 4.3. Kiểm tra file đã thêm đúng

- File `.gif` xuất hiện trong Project Navigator → thư mục **Resources**
- Click chọn file → **File Inspector** bên phải → kiểm tra **Target Membership** đã tick `NetflixClone`

> ⚠️ **Không thêm GIF vào Assets.xcassets** — Assets catalog không hỗ trợ animated GIF.
> Phải để file `.gif` trực tiếp trong thư mục (như ảnh trên).

---

## 5. BƯỚC 3 — Tạo SplashViewController (XIB)

> **Mục tiêu:** Tạo màn hình splash với nền đen, GIF animation ở giữa, tự chuyển sang Login sau khi GIF kết thúc (hoặc sau N giây).

### 5.1. Tạo file trong Xcode

1. Click phải vào folder **Controllers** → **New File...**
2. Chọn template: **iOS → Cocoa Touch Class**
3. Điền:
   - **Class:** `SplashViewController`
   - **Subclass of:** `UIViewController`
   - ✅ **Also create XIB file** ← tick vào!
   - **Language:** Swift
4. Nhấn **Next** → **Create**

> Xcode tạo 2 file: `SplashViewController.swift` + `SplashViewController.xib`

### 5.2. Thiết kế trong XIB (`SplashViewController.xib`)

Splash screen đơn giản: nền đen + GIF ở giữa. Không cần kéo view phức tạp — `SDAnimatedImageView` sẽ thêm bằng code.

#### A. Set màu nền root view

1. Chọn **View** (root view) trong Document Outline
2. **Attributes Inspector** → Background: **Black Color**

#### B. Không cần kéo thêm gì trong XIB

`SDAnimatedImageView` sẽ được tạo hoàn toàn bằng code, vì XIB không nhận diện được custom class từ pod.

> Bạn vẫn có thể kéo UIImageView vào XIB và đổi Custom Class thành `SDAnimatedImageView`
> nếu muốn dùng Auto Layout trực quan. Nhưng cách làm bằng code đơn giản và ít lỗi hơn.

### 5.3. Viết code `SplashViewController.swift`

```swift
//
//  SplashViewController.swift
//  NetflixClone
//

import UIKit
import SDWebImage

class SplashViewController: UIViewController {

    // MARK: - Properties

    /// Thời gian tối đa hiển thị splash (giây)
    /// Nếu GIF ngắn hơn, sẽ tự chuyển khi GIF kết thúc.
    /// Nếu GIF dài hơn, sẽ chuyển sau đúng N giây này.
    private let splashDuration: TimeInterval = 3.0

    private var animationImageView: SDAnimatedImageView!
    private var hasNavigated = false   // Tránh navigate 2 lần

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupGIFAnimation()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSplashTimer()
    }

    // MARK: - Setup

    private func setupGIFAnimation() {
        // Tên file phải khớp với file .gif đã thêm vào Resources (CÓ đuôi .gif)
        guard let gifURL = Bundle.main.url(forResource: "splash_animation", withExtension: "gif"),
              let gifData = try? Data(contentsOf: gifURL),
              let animatedImage = SDAnimatedImage(data: gifData) else {
            // Nếu không load được GIF → chuyển ngay sang Login
            print("⚠️ SplashViewController: Không tìm thấy splash_animation.gif")
            navigateToLogin()
            return
        }

        // Tạo animated image view và đặt ở giữa màn hình
        animationImageView = SDAnimatedImageView()
        animationImageView.image = animatedImage
        animationImageView.contentMode = .scaleAspectFit
        animationImageView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(animationImageView)

        // Auto Layout: căn giữa, kích thước 250x250
        NSLayoutConstraint.activate([
            animationImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            animationImageView.widthAnchor.constraint(equalToConstant: 250),
            animationImageView.heightAnchor.constraint(equalToConstant: 250)
        ])

        // Bắt đầu play GIF
        animationImageView.startAnimating()
    }

    // MARK: - Timer

    private func startSplashTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) { [weak self] in
            self?.navigateToLogin()
        }
    }

    // MARK: - Navigation

    private func navigateToLogin() {
        // Đảm bảo chỉ navigate 1 lần duy nhất
        guard !hasNavigated else { return }
        hasNavigated = true

        let loginVC = LoginViewController(nibName: "LoginViewController", bundle: nil)
        loginVC.modalPresentationStyle = .fullScreen
        loginVC.modalTransitionStyle = .crossDissolve   // Hiệu ứng fade mượt
        present(loginVC, animated: true)
    }
}
```

### 5.4. Điều chỉnh kích thước & vị trí GIF

Bạn có thể thay đổi các giá trị sau trong code:

| Thuộc tính | Dòng code | Giá trị mặc định | Gợi ý thay thế |
|---|---|---|---|
| Thời gian splash | `splashDuration` | `3.0` giây | `2.0` – `4.0` |
| Chiều rộng GIF | `widthAnchor ... 250` | 250 pt | 200 – 300 pt |
| Chiều cao GIF | `heightAnchor ... 250` | 250 pt | 200 – 300 pt |
| Content mode | `contentMode = .scaleAspectFit` | Giữ tỷ lệ | `.scaleAspectFill` nếu GIF full screen |

### 5.5. Giải thích code quan trọng

```swift
// ❌ UIImage thông thường — CHỈ hiện frame đầu của GIF
let image = UIImage(named: "splash_animation")

// ✅ SDAnimatedImage — đọc toàn bộ GIF với đầy đủ frame và timing
let image = SDAnimatedImage(data: gifData)

// ✅ SDAnimatedImageView — UIImageView đặc biệt biết cách phát các frame theo đúng timing
let view = SDAnimatedImageView()
view.image = image
view.startAnimating()
```

---

## 6. BƯỚC 4 — Tạo LoginViewController (XIB)

> **Mục tiêu:** Tái tạo giao diện đăng nhập như hình — nền collage poster phim, NETFLIX logo, Email/Password fields, Sign In button, và Google/Facebook sign-in.

### 6.1. Tạo file trong Xcode

1. Click phải vào folder **Controllers** → **New File...**
2. Chọn template: **iOS → Cocoa Touch Class**
3. Điền:
   - **Class:** `LoginViewController`
   - **Subclass of:** `UIViewController`
   - ✅ **Also create XIB file** ← tick vào!
   - **Language:** Swift
4. Nhấn **Next** → **Create**

### 6.2. Thiết kế trong XIB (`LoginViewController.xib`)

#### Cấu trúc View Hierarchy

```
LoginViewController (root)
└── View (root view)
    ├── backgroundImageView (UIImageView)    ← full screen, ảnh collage poster
    ├── overlayView (UIView)                 ← gradient đen bán trong suốt
    ├── netflixLogoLabel (UILabel)           ← "NETFLIX" chữ đỏ, to
    ├── emailTextField (UITextField)         ← viền đỏ, nền đen
    ├── passwordTextField (UITextField)      ← viền đỏ, nền đen, isSecureTextEntry
    ├── signInButton (UIButton)              ← nền đỏ, chữ trắng "Sign in"
    ├── bottomLabel (UILabel)               ← "Is it first time for you? Sign up now"
    ├── orLabel (UILabel)                   ← "Or sign in with"
    └── socialStackView (UIStackView)       ← chứa Google + Facebook button
        ├── googleButton (UIButton)
        └── facebookButton (UIButton)
```

#### A. Set màu nền root view

- Chọn **View** → Background: **Black Color**

#### B. Thêm Background Image (nền collage)

1. Kéo **UIImageView** vào root view
2. **Constraints**: Top = 0, Bottom = 0, Leading = 0, Trailing = 0
   - Click nút 📌 → bỏ tick **Constrain to margins** → đặt đều 4 cạnh = 0
3. **Attributes Inspector**:
   - Image: _(để trống — code sẽ set hoặc để nền đen)_
   - Content Mode: **Aspect Fill**
   - ✅ Clip to Bounds
   - Background: **Dark Gray Color** _(placeholder khi chưa có ảnh)_

> 💡 **Để có ảnh collage như hình mẫu:** Bạn có thể thêm ảnh vào **Assets.xcassets** rồi set `backgroundImageView.image = UIImage(named: "login_bg")` trong code.
> Hoặc để nền tối đơn giản cũng ổn.

#### C. Thêm Overlay (lớp đen mờ phía trên ảnh nền)

1. Kéo **UIView** vào, đặt lên trên `backgroundImageView`
2. **Constraints**: Top = 0, Bottom = 0, Leading = 0, Trailing = 0 (giống background)
3. **Attributes Inspector**: Background = **Black Color** _(code sẽ set alpha = 0.5)_

#### D. Thêm NETFLIX Logo Label

1. Kéo **UILabel** vào
2. **Constraints**:
   - Top = **280** so với root view top
   - Center X: **Editor → Align → Horizontally in Container**
3. **Attributes Inspector**:
   - Text: `"NETFLIX"`
   - Font: **System Black, 42** _(hoặc Bold)_
   - Color: **Red** _(custom: R=229, G=9, B=20)_
   - Alignment: **Center**

#### E. Thêm Email TextField

1. Kéo **UITextField** vào
2. **Constraints**:
   - Top = **32** so với **netflixLogoLabel.bottom**
   - Leading = **24** so với root view
   - Trailing = **-24** so với root view
   - Height: **52**
3. **Attributes Inspector**:
   - Placeholder: `"Email"`
   - Text Color: **White**
   - Background Color: **Black Color**
   - Border Style: **None** _(border đỏ thêm bằng code)_
   - Keyboard Type: **Email Address**
   - Return Key: **Next**

#### F. Thêm Password TextField

1. Kéo **UITextField** vào
2. **Constraints**:
   - Top = **16** so với **emailTextField.bottom**
   - Leading = **24**, Trailing = **-24**
   - Height: **52**
3. **Attributes Inspector**:
   - Placeholder: `"Password"`
   - Text Color: **White**
   - Background Color: **Black**
   - Border Style: **None**
   - ✅ **Secure Text Entry** ← tick vào!
   - Return Key: **Done**

#### G. Thêm Sign In Button

1. Kéo **UIButton** vào
2. **Constraints**:
   - Top = **24** so với **passwordTextField.bottom**
   - Leading = **24**, Trailing = **-24**
   - Height: **52**
3. **Attributes Inspector**:
   - Title: `"Sign in"`
   - Font: **System Bold, 18**
   - Text Color: **White**
   - Background Color: **Red** _(R=229, G=9, B=20)_

#### H. Thêm Bottom Label

1. Kéo **UILabel** vào
2. **Constraints**:
   - Top = **20** so với **signInButton.bottom**
   - Center X in container
3. **Attributes Inspector**:
   - Text: `"Is it first time for you? Sign up now"`
   - Font: **System, 14**
   - Color: **White**
   - Alignment: **Center**

#### I. Thêm "Or sign in with" Label

1. Kéo **UILabel** vào
2. **Constraints**:
   - Top = **8** so với **bottomLabel.bottom**
   - Center X in container
3. **Attributes Inspector**:
   - Text: `"Or sign in with"`
   - Font: **System, 14**
   - Color: **Light Gray**
   - Alignment: **Center**

#### J. Thêm Google + Facebook Button trong StackView

1. Kéo **UIButton** vào (Google):
   - Title: `"G"` · Font Bold 20 · Text white · Background: White  
   - Width = **48**, Height = **48**

2. Kéo **UIButton** thứ hai (Facebook):
   - Title: `"f"` · Font Bold 20 · Text white · Background: Blue

3. Chọn cả 2 button → **Editor → Embed In → Stack View**:
   - Axis: **Horizontal** · Spacing: **16** · Alignment: **Center**

4. Constraints cho StackView:
   - Top = **16** so với **orLabel.bottom**
   - Center X in container
   - **Bottom = 40** so với root view ← **RẤT QUAN TRỌNG** (để VC biết tổng chiều cao)

### 6.3. Tạo IBOutlets và IBActions

Mở **Assistant Editor** (`Ctrl + Option + Cmd + Enter`), **Ctrl + kéo** từng element:

| Element | Tên Outlet | Loại |
|---|---|---|
| Background UIImageView | `backgroundImageView` | `@IBOutlet UIImageView` |
| Overlay UIView | `overlayView` | `@IBOutlet UIView` |
| NETFLIX UILabel | `netflixLogoLabel` | `@IBOutlet UILabel` |
| Email UITextField | `emailTextField` | `@IBOutlet UITextField` |
| Password UITextField | `passwordTextField` | `@IBOutlet UITextField` |
| Sign In UIButton | `signInButton` | `@IBOutlet UIButton` |
| Bottom UILabel | `bottomLabel` | `@IBOutlet UILabel` |
| Google UIButton | `googleButton` | `@IBOutlet UIButton` |
| Facebook UIButton | `facebookButton` | `@IBOutlet UIButton` |

**IBActions:**

| Element | Action Name |
|---|---|
| Sign In UIButton | `signInTapped(_:)` |
| Google UIButton | `googleSignInTapped(_:)` |
| Facebook UIButton | `facebookSignInTapped(_:)` |

### 6.4. Viết code `LoginViewController.swift`

```swift
//
//  LoginViewController.swift
//  NetflixClone
//

import UIKit

class LoginViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var netflixLogoLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var googleButton: UIButton!
    @IBOutlet weak var facebookButton: UIButton!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .black

        // Overlay: lớp đen mờ phủ lên ảnh nền
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        // Logo NETFLIX
        netflixLogoLabel.text = "NETFLIX"
        netflixLogoLabel.textColor = UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1)
        netflixLogoLabel.font = .systemFont(ofSize: 42, weight: .black)

        // TextFields
        styleTextField(emailTextField, placeholder: "Email")
        emailTextField.keyboardType = .emailAddress
        emailTextField.returnKeyType = .next
        emailTextField.delegate = self

        styleTextField(passwordTextField, placeholder: "Password")
        passwordTextField.isSecureTextEntry = true
        passwordTextField.returnKeyType = .done
        passwordTextField.delegate = self

        // Buttons
        styleSignInButton()
        styleCircleButton(googleButton,
                          title: "G",
                          textColor: UIColor(red: 66/255, green: 133/255, blue: 244/255, alpha: 1),
                          bgColor: .white)
        styleCircleButton(facebookButton,
                          title: "f",
                          textColor: .white,
                          bgColor: UIColor(red: 66/255, green: 103/255, blue: 178/255, alpha: 1))

        // Bottom label: "Sign up now" màu đỏ
        styleBottomLabel()

        // Dismiss keyboard khi tap ra ngoài
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    // MARK: - Style Helpers

    private func styleTextField(_ textField: UITextField, placeholder: String) {
        textField.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        textField.textColor = .white
        textField.tintColor = .white
        textField.layer.borderColor = UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1).cgColor
        textField.layer.borderWidth = 1.5
        textField.layer.cornerRadius = 8
        textField.clipsToBounds = true

        // Padding bên trái
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        textField.leftView = paddingView
        textField.leftViewMode = .always

        // Placeholder màu xám
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.lightGray]
        )
    }

    private func styleSignInButton() {
        signInButton.setTitle("Sign in", for: .normal)
        signInButton.setTitleColor(.white, for: .normal)
        signInButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        signInButton.backgroundColor = UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1)
        signInButton.layer.cornerRadius = 8
        signInButton.clipsToBounds = true
    }

    private func styleCircleButton(_ button: UIButton, title: String, textColor: UIColor, bgColor: UIColor) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(textColor, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        button.backgroundColor = bgColor
        button.layer.cornerRadius = 24   // width = height = 48 → tròn hoàn hảo
        button.clipsToBounds = true
    }

    private func styleBottomLabel() {
        let fullText = "Is it first time for you? Sign up now"
        let attributed = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 14)
            ]
        )
        if let range = fullText.range(of: "Sign up now") {
            let nsRange = NSRange(range, in: fullText)
            attributed.addAttributes([
                .foregroundColor: UIColor(red: 229/255, green: 9/255, blue: 20/255, alpha: 1),
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
            ], range: nsRange)
        }
        bottomLabel.attributedText = attributed
        bottomLabel.textAlignment = .center
        bottomLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(signUpTapped))
        bottomLabel.addGestureRecognizer(tap)
    }

    // MARK: - IBActions

    @IBAction func signInTapped(_ sender: UIButton) {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(message: "Vui lòng nhập email và password.")
            return
        }
        // TODO: Gọi API đăng nhập thật ở đây
        navigateToMainApp()
    }

    @IBAction func googleSignInTapped(_ sender: UIButton) {
        // TODO: Tích hợp Google Sign-In SDK
        print("Google Sign In tapped")
    }

    @IBAction func facebookSignInTapped(_ sender: UIButton) {
        // TODO: Tích hợp Facebook Login SDK
        print("Facebook Sign In tapped")
    }

    @objc private func signUpTapped() {
        // TODO: Điều hướng đến màn hình đăng ký
        print("Sign Up tapped")
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Navigation

    private func navigateToMainApp() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            window.rootViewController = MainTabBarViewController()
        }
    }

    // MARK: - Helper

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            passwordTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
```

### 6.5. Những gì KHÔNG THỂ làm trong XIB (cần code)

| Thuộc tính | XIB? | Code? | Ở đâu |
|---|---|---|---|
| Border color (UIColor) | ❌ | ✅ | `styleTextField()` |
| Border width | ❌ | ✅ | `styleTextField()` |
| Corner radius | ❌ | ✅ | `styleTextField()`, `styleSignInButton()` |
| TextField padding (leftView) | ❌ | ✅ | `styleTextField()` |
| Attributed text (nhiều màu) | ❌ | ✅ | `styleBottomLabel()` |
| Placeholder màu custom | ❌ | ✅ | `styleTextField()` |

---

## 7. BƯỚC 5 — Cập nhật SceneDelegate để bắt đầu từ Splash

> **Mục tiêu:** Thay đổi màn hình đầu tiên từ `MainTabBarViewController` sang `SplashViewController`.

### 7.1. Mở file `SceneDelegate.swift`

### 7.2. Sửa hàm `scene(_:willConnectTo:)`

**Trước (code cũ):**

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    window = UIWindow(frame: windowScene.coordinateSpace.bounds)
    window?.windowScene = windowScene
    window?.rootViewController = MainTabBarViewController()   // ← Cần đổi
    window?.makeKeyAndVisible()
}
```

**Sau (code mới):**

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    window = UIWindow(frame: windowScene.coordinateSpace.bounds)
    window?.windowScene = windowScene

    // ✅ Bắt đầu ở SplashViewController
    let splashVC = SplashViewController(nibName: "SplashViewController", bundle: nil)
    window?.rootViewController = splashVC

    window?.makeKeyAndVisible()
}
```

### 7.3. Tại sao phải dùng `nibName:bundle:` ?

```swift
// ❌ SAI — UIViewController() tìm Storyboard, không tìm XIB
let vc = SplashViewController()

// ✅ ĐÚNG — Chỉ định rõ file XIB
let vc = SplashViewController(nibName: "SplashViewController", bundle: nil)
```

> **Quy tắc:** ViewController dùng XIB (không phải Storyboard) phải khởi tạo với `nibName:bundle:`.
> `nibName` phải **khớp chính xác** tên file `.xib` — **phân biệt hoa thường**.

### 7.4. Build và chạy

`Cmd + R` — kết quả mong đợi:

| Thứ tự | Màn hình | Ghi chú |
|---|---|---|
| 1 | Nền đen + GIF animation chạy ở giữa | SplashViewController |
| 2 | Hiệu ứng fade → Login screen | Sau `splashDuration` giây (mặc định 3s) |
| 3 | Nhập email + password → Sign in | LoginViewController |
| 4 | Vào app chính | MainTabBarViewController |

---

## 8. Tổng kết & Checklist

### ✅ Checklist đầy đủ

#### Bước 1 — Cài SDWebImage
- [ ] Thêm `pod 'SDWebImage'` vào Podfile
- [ ] Chạy `pod install` thành công
- [ ] Build `Cmd + B` — không lỗi

#### Bước 2 — File GIF
- [ ] Đặt tên file là `splash_animation.gif`
- [ ] Thêm vào folder **Resources** trong Xcode (**không** vào Assets.xcassets)
- [ ] Tick ✅ Copy items if needed, ✅ Target Membership: NetflixClone

#### Bước 3 — SplashViewController
- [ ] Tạo file với XIB (**Cocoa Touch Class**, Subclass = UIViewController, ✅ XIB)
- [ ] Root view background = **Black**
- [ ] Viết code `setupGIFAnimation()` với `SDAnimatedImageView`
- [ ] Đổi `splashDuration` nếu muốn (mặc định 3 giây)
- [ ] Build `Cmd + B` — không lỗi

#### Bước 4 — LoginViewController
- [ ] Tạo file với XIB
- [ ] Thêm đủ elements: background, overlay, logo, 2 textfields, 1 button, 2 labels, 2 social buttons
- [ ] Tất cả Auto Layout đầy đủ, đặc biệt **constraint Bottom** cho StackView
- [ ] Kết nối đủ 9 IBOutlets + 3 IBActions
- [ ] Viết code `setupUI()` đầy đủ
- [ ] Build `Cmd + B` — không lỗi

#### Bước 5 — SceneDelegate
- [ ] Đổi thành `SplashViewController(nibName: "SplashViewController", bundle: nil)`
- [ ] Chạy app `Cmd + R` → splash → login → main app ✅

### 🔍 Debug thường gặp

| Lỗi | Nguyên nhân | Cách fix |
|---|---|---|
| GIF không chạy — chỉ hiện frame đầu | Dùng `UIImageView` thông thường | Phải dùng `SDAnimatedImageView` |
| `SDAnimatedImage(data:)` trả về nil | Tên file sai hoặc chưa add target | Kiểm tra tên file và Target Membership |
| GIF không tìm thấy (Bundle.main.url trả về nil) | File không được add vào bundle | ✅ Tick Target Membership khi Add files |
| Login hiện dạng sheet (kéo được xuống) | iOS 13+ dùng sheet mặc định | Thêm `loginVC.modalPresentationStyle = .fullScreen` |
| `IBOutlet` nil — app crash | Quên kết nối outlet trong XIB | Ctrl+kéo lại; kiểm tra chấm tròn ở code margin |
| App crash: `loaded the nib but didn't get a UIViewController` | XIB root object sai | Chọn root object trong XIB → Custom Class = `SplashViewController` |
| Keyboard che mất Sign In button | Không handle keyboard | Thêm `NotificationCenter` observer `keyboardWillShow` → adjust constraint |

### 🧩 Các tính năng có thể mở rộng thêm

| Tính năng | Gợi ý cách làm |
|---|---|
| Background collage poster động | Gọi TMDB trending API → lấy poster → ghép UICollectionView ở background |
| Nhớ login session | Lưu token vào `Keychain` bằng `Security.framework` |
| Skip splash nếu đã login | Kiểm tra token trong Keychain ở `SceneDelegate` → nhảy thẳng vào MainTabBar |
| Validate email format | `NSPredicate` với regex email |
| Loading spinner khi sign in | `UIActivityIndicatorView` trong `signInTapped` |
| Splash chỉ show 1 lần | Lưu `UserDefaults.standard.bool(forKey: "hasSeenSplash")` |
