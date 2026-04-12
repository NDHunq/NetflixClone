//
//  MovieDetailViewController.swift
//  NetflixClone
//
//  Created by NDHunq on 12/4/26.
//

import UIKit

private enum DetailSection: Int, CaseIterable {
    case backdrop = 0    // MovieBackdropCell
    case actions  = 1    // MovieActionCell
    case overview = 2    // MovieOverviewCell
    case cast     = 3    // MovieCastCell
}

class MovieDetailViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    private var movieId: Int = 0
    private var movieDetail: MovieDetail?
    private var castMembers: [CastMember] = []
    private var trailerKey: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTableView()
        fetchAllData()
    }
    
    func configure(with movieId: Int) {
        self.movieId = movieId
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        // Đăng ký 4 cell XIB bằng UINib
        tableView.register(
            UINib(nibName: "MovieBackdropCell", bundle: nil),
            forCellReuseIdentifier: MovieBackdropCell.identifier
        )
        tableView.register(
            UINib(nibName: "MovieActionCell", bundle: nil),
            forCellReuseIdentifier: MovieActionCell.identifier
        )
        tableView.register(
            UINib(nibName: "MovieOverviewCell", bundle: nil),
            forCellReuseIdentifier: MovieOverviewCell.identifier
        )
        tableView.register(
            UINib(nibName: "MovieCastCell", bundle: nil),
            forCellReuseIdentifier: MovieCastCell.identifier
        )
        
        // Self-sizing cells
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        
        // Ẩn separator
        tableView.separatorStyle = .none
        
        // Cho phép table view scroll under navigation bar
        tableView.contentInsetAdjustmentBehavior = .never
    }
    private func fetchAllData() {
        fetchMovieDetail()
        fetchMovieCredits()
        fetchMovieVideos()
    }
    
    private func fetchMovieDetail() {
        APICaller.shared.getMovieDetail(movieId: movieId) { [weak self] result in
            switch result {
            case .success(let detail):
                DispatchQueue.main.async {
                    self?.movieDetail = detail
                    self?.navigationItem.title = detail.title
                    // Reload backdrop + overview sections
                    self?.tableView.reloadSections(
                        IndexSet([DetailSection.backdrop.rawValue, DetailSection.overview.rawValue]),
                        with: .automatic
                    )
                }
            case .failure(let error):
                print("[MovieDetailVC] Detail error: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchMovieCredits() {
        APICaller.shared.getMovieCredits(movieId: movieId) { [weak self] result in
            switch result {
            case .success(let cast):
                DispatchQueue.main.async {
                    self?.castMembers = cast
                    self?.tableView.reloadSections(
                        IndexSet([DetailSection.cast.rawValue]),
                        with: .automatic
                    )
                }
            case .failure(let error):
                print("[MovieDetailVC] Credits error: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchMovieVideos() {
        APICaller.shared.getMovieVideos(movieId: movieId) { [weak self] result in
            switch result {
            case .success(let videos):
                // Lọc trailer YouTube đầu tiên
                let trailer = videos.first { $0.type == "Trailer" && $0.site == "YouTube" }
                DispatchQueue.main.async {
                    self?.trailerKey = trailer?.key
                    self?.tableView.reloadSections(
                        IndexSet([DetailSection.actions.rawValue]),
                        with: .automatic
                    )
                }
            case .failure(let error):
                print("[MovieDetailVC] Videos error: \(error.localizedDescription)")
            }
        }
    }
}

extension MovieDetailViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return DetailSection.allCases.count  // 4 sections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1  // mỗi section chỉ có 1 row
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = DetailSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch section {
        case .backdrop:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieBackdropCell.identifier,
                for: indexPath
            ) as! MovieBackdropCell
            
            if let detail = movieDetail {
                cell.configure(with: detail)
            }
            return cell
            
        case .actions:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieActionCell.identifier,
                for: indexPath
            ) as! MovieActionCell
            
            cell.delegate = self  // để nhận sự kiện tap button
            cell.configure(hasTrailer: trailerKey != nil)
            return cell
            
        case .overview:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieOverviewCell.identifier,
                for: indexPath
            ) as! MovieOverviewCell
            
            cell.configure(with: movieDetail?.overview)
            return cell
            
        case .cast:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieCastCell.identifier,
                for: indexPath
            ) as! MovieCastCell
            
            cell.configure(with: castMembers)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension MovieDetailViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension MovieDetailViewController: MovieActionCellDelegate {
    
    func movieActionCellDidTapPlayTrailer(_ cell: MovieActionCell) {
        guard let key = trailerKey,
              let url = URL(string: "https://www.youtube.com/watch?v=\(key)") else {
            print("[MovieDetailVC] No trailer available")
            return
        }
        UIApplication.shared.open(url)
    }
    
    func movieActionCellDidTapDownload(_ cell: MovieActionCell) {
        // TODO: Implement download feature
        print("[MovieDetailVC] Download tapped — chưa implement")
    }
}
