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
        tableView.register(
            UINib(nibName: "MovieBackdropTableViewCell", bundle: nil),
            forCellReuseIdentifier: MovieBackdropTableViewCell.identifier
        )
        tableView.register(
            UINib(nibName: "MovieActionTableViewCell", bundle: nil),
            forCellReuseIdentifier: MovieActionTableViewCell.identifier
        )
        tableView.register(
            UINib(nibName: "MovieOverviewTableViewCell", bundle: nil),
            forCellReuseIdentifier: MovieOverviewTableViewCell.identifier
        )
        tableView.register(
            UINib(nibName: "MovieCastTableViewCell", bundle: nil),
            forCellReuseIdentifier: MovieCastTableViewCell.identifier
        )
        
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
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
        return DetailSection.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = DetailSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch section {
        case .backdrop:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieBackdropTableViewCell.identifier,
                for: indexPath
            ) as! MovieBackdropTableViewCell
            
            if let detail = movieDetail {
                cell.configure(with: detail)
            }
            return cell
            
        case .actions:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieActionTableViewCell.identifier,
                for: indexPath
            ) as! MovieActionTableViewCell
            
            cell.delegate = self
            cell.configure(hasTrailer: trailerKey != nil)
            return cell
            
        case .overview:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieOverviewTableViewCell.identifier,
                for: indexPath
            ) as! MovieOverviewTableViewCell
            
            cell.configure(with: movieDetail?.overview)
            return cell
            
        case .cast:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MovieCastTableViewCell.identifier,
                for: indexPath
            ) as! MovieCastTableViewCell
            
            cell.configure(with: castMembers)
            return cell
        }
    }
}

extension MovieDetailViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension MovieDetailViewController: MovieActionCellDelegate {
    
    func movieActionCellDidTapPlayTrailer(_ cell: MovieActionTableViewCell) {
        guard let key = trailerKey,
              let url = URL(string: "https://www.youtube.com/watch?v=\(key)") else {
            print("[MovieDetailVC] No trailer available")
            return
        }
        UIApplication.shared.open(url)
    }
    
    func movieActionCellDidTapDownload(_ cell: MovieActionTableViewCell) {
        // TODO: Implement download feature
        print("[MovieDetailVC] Download tapped — chưa implement")
    }
}
