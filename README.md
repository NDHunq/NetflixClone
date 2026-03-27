# Netflix Clone 🎬

A Netflix-inspired iOS application built with Swift and UIKit. The app fetches real movie and TV show data from The Movie Database (TMDB) API and displays it in a familiar Netflix-style interface.

## Screenshots

> *(Add screenshots of your app here)*

## Features

- 🏠 **Home Screen** — Hero header banner with Play & Download buttons; horizontally scrollable content rows
- 📅 **Coming Soon** — Browse upcoming movie releases
- 🔍 **Top Search** — Discover top-searched titles
- ⬇️ **Downloads** — Manage downloaded titles for offline viewing
- 🎞️ **Content Sections**
  - Trending Movies
  - Trending TV Shows
  - Popular
  - Upcoming Movies
  - Top Rated

## Architecture

The project follows **MVC (Model-View-Controller)** pattern and is built entirely programmatically (no Storyboards).

```
NetflixClone/
├── Controllers/
│   ├── HomeViewController.swift        # Main feed with categorized content rows
│   ├── UpcomingViewController.swift    # Upcoming movies tab
│   ├── SearchViewController.swift      # Search tab
│   └── DownloadsViewController.swift   # Downloads tab
├── Views/
│   ├── HeroHeaderUIView.swift          # Large hero banner at the top of Home
│   ├── CollectionViewTableViewCell.swift  # Horizontal scroll row for each section
│   └── TitleCollectionViewCell.swift   # Individual movie/show poster cell
├── Models/
│   └── Title.swift                     # Codable model for movie/TV titles
├── Managers/
│   └── APICaller.swift                 # Singleton network layer for TMDB API
├── Resources/
│   └── Extensions.swift                # Swift extensions
└── MainTabBarViewController.swift      # Root tab bar controller
```

## Tech Stack

| Technology | Usage |
|---|---|
| Swift 5 | Primary language |
| UIKit | UI framework (programmatic, no Storyboards) |
| URLSession | Native networking |
| [SDWebImage](https://github.com/SDWebImage/SDWebImage) | Async image loading & caching |
| Swift Package Manager | Dependency management |
| [TMDB API](https://www.themoviedb.org/documentation/api) | Movie & TV show data source |

## Requirements

- iOS 14.0+
- Xcode 13+
- Swift 5.5+
- A valid [TMDB API key](https://developers.themoviedb.org/3/getting-started/introduction)

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/NDHunq/NetflixClone.git
   cd NetflixClone
   ```

2. **Open the project in Xcode**
   ```bash
   open NetflixClone.xcodeproj
   ```

3. **Resolve Swift Package dependencies**

   In Xcode: **File → Packages → Resolve Package Versions**
   
   SDWebImage will be downloaded automatically via Swift Package Manager.

4. **Configure your TMDB API Key**

   Open `Managers/APICaller.swift` and replace the placeholder key:
   ```swift
   struct Constants {
       static let API_KEY = "YOUR_TMDB_API_KEY_HERE"
       static let baseURL = "https://api.themoviedb.org"
   }
   ```
   > ⚠️ **Important:** Never commit your real API key to source control. Consider using a `.xcconfig` file or environment variables to manage secrets.

5. **Build and run**

   Select a simulator or physical device and press `⌘ + R`.

## API Endpoints Used

| Function | Endpoint |
|---|---|
| Trending Movies | `/3/trending/movie/day` |
| Trending TV Shows | `/3/trending/tv/day` |
| Popular Movies | `/3/movie/popular` |
| Upcoming Movies | `/3/movie/upcoming` |
| Top Rated Movies | `/3/movie/top_rated` |

All responses are decoded into the `Title` model which captures id, media type, title, poster path, overview, vote count, release date, and vote average.

## Dependencies

| Package | Version | License |
|---|---|---|
| [SDWebImage](https://github.com/SDWebImage/SDWebImage) | Latest | MIT |

## Author

**Nguyen Duy Hung**  
GitHub: [@NDHunq](https://github.com/NDHunq)

## License

This project is for educational and learning purposes only. All movie/TV data is provided by [The Movie Database (TMDB)](https://www.themoviedb.org/). Netflix trademarks and branding are the property of Netflix, Inc.
