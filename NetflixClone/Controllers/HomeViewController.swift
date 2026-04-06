//
//  HomeViewController.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 24/3/26.
//

import UIKit

enum Sections: Int{
    case TrendingMovies = 0
    case TrendingTV = 1
    case Popular = 2
    case UpcomingMovies = 3
    case TopRated = 4
}

class HomeViewController: UIViewController {
    
    let sectionTiles: [String] = ["Trending Movies", "Trending TV", "Popular", "Upcoming Movies", "Top Rated"]
    
    private let homeFeedTable: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.register(CollectionViewTableViewCell.self, forCellReuseIdentifier: CollectionViewTableViewCell.indentifier)
        return table
    }()

    override func viewDidLoad() {
        URLCache.shared.removeAllCachedResponses()
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(homeFeedTable)
        
        homeFeedTable.delegate = self
        homeFeedTable.dataSource = self
        
        configureNavBar()
        
        let headerView = HeroHeaderUIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 450))
        homeFeedTable.tableHeaderView = headerView

        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.homeFeedTable.reloadData()
        }
    }
    
    private func configureNavBar() {
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "person"), style:.done, target: self, action: nil),
            UIBarButtonItem(image: UIImage(systemName: "play.rectangle"), style:.done, target: self, action: nil)
        ]
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.backgroundColor = .clear
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        homeFeedTable.frame = view.bounds
    }

}

extension HomeViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        sectionTiles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CollectionViewTableViewCell.indentifier, for: indexPath) as? CollectionViewTableViewCell else {
            return UITableViewCell()
        }
        switch indexPath.section {
        case Sections.TrendingMovies.rawValue:
            APICaller.shared.getTrendingMovies { [weak self] result in
                switch result {
                case .success(let titles):
                    cell.configure(with: titles)
                    DispatchQueue.global(qos: .utility).async {
                        DatabaseManager.shared.saveTitles(titles, section: "trending_movies")
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                    DispatchQueue.global(qos: .userInitiated).async {
                        let cached = DatabaseManager.shared.fetchTitles(section: "trending_movies")
                        DispatchQueue.main.async {
                            if !cached.isEmpty {
                                cell.configure(with: cached)
                                print("Loaded \(cached.count) phim từ cache")
                            } else {
                                print("Không có cache")
                            }
                        }
                    }
                }
            }
        case Sections.TrendingTV.rawValue:
            APICaller.shared.getTrendingTVs { [weak self] result in
                switch result {
                case .success(let titles):
                    cell.configure(with: titles)
                    DispatchQueue.global(qos: .utility).async {
                        DatabaseManager.shared.saveTitles(titles, section: "trending_tv")
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                    DispatchQueue.global(qos: .userInitiated).async {
                        let cached = DatabaseManager.shared.fetchTitles(section: "trending_tv")
                        DispatchQueue.main.async {
                            if !cached.isEmpty {
                                cell.configure(with: cached)
                                print("Loaded \(cached.count) phim từ cache")
                            } else {
                                print("Không có cache")
                            }
                        }
                    }
                }
            }
        case Sections.Popular.rawValue:
            APICaller.shared.getPopularMovies { [weak self] result in
                switch result {
                case .success(let titles):
                    cell.configure(with: titles)
                    DispatchQueue.global(qos: .utility).async {
                        DatabaseManager.shared.saveTitles(titles, section: "popular")
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                    DispatchQueue.global(qos: .userInitiated).async {
                        let cached = DatabaseManager.shared.fetchTitles(section: "popular")
                        DispatchQueue.main.async {
                            if !cached.isEmpty {
                                cell.configure(with: cached)
                                print("Loaded \(cached.count) phim từ cache")
                            } else {
                                print("Không có cache")
                            }
                        }
                    }
                }
            }
        case Sections.UpcomingMovies.rawValue:
            APICaller.shared.getUpcomingMovies { [weak self] result in
                switch result {
                case .success(let titles):
                    cell.configure(with: titles)
                    DispatchQueue.global(qos: .utility).async {
                        DatabaseManager.shared.saveTitles(titles, section: "upcoming")
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                    DispatchQueue.global(qos: .userInitiated).async {
                        let cached = DatabaseManager.shared.fetchTitles(section: "upcoming")
                        DispatchQueue.main.async {
                            if !cached.isEmpty {
                                cell.configure(with: cached)
                                print("Loaded \(cached.count) phim từ cache")
                            } else {
                                print("Không có cache")
                            }
                        }
                    }
                }
            }
        case Sections.TopRated.rawValue:
            APICaller.shared.getTopRated { [weak self] result in
                switch result {
                case .success(let titles):
                    cell.configure(with: titles)
                    DispatchQueue.global(qos: .utility).async {
                        DatabaseManager.shared.saveTitles(titles, section: "top_rated")
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                    DispatchQueue.global(qos: .userInitiated).async {
                        let cached = DatabaseManager.shared.fetchTitles(section: "top_rated")
                        DispatchQueue.main.async {
                            if !cached.isEmpty {
                                cell.configure(with: cached)
                                print("Loaded \(cached.count) phim từ cache")
                            } else {
                                print("Không có cache")
                            }
                        }
                    }
                }
            }
        default:
            return UITableViewCell()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTiles[section]
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        header.textLabel?.frame = CGRect(x: header.bounds.origin.x + 20, y: header.bounds.origin.y, width: 100, height: header.bounds.height)
    }
    
}
