//
//  UpcomingViewController.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 24/3/26.
//

import UIKit

class UpcomingViewController: UIViewController {
    
    private var titles: [Title] = [Title]()
    
    private let upcomingTable: UITableView = {
        let table = UITableView()
        table.register(TitleTableViewCell.self, forCellReuseIdentifier: TitleTableViewCell.identifier)
        return table
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Upcoming"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationItem.largeTitleDisplayMode = .always
        
        view.addSubview(upcomingTable)
        upcomingTable.delegate = self
        upcomingTable.dataSource = self
        
        fetchUpcoming()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        upcomingTable.frame = view.bounds
    }
    
    private func fetchUpcoming() {
        // BƯỚC 1: Load cache NGAY - không chờ API
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let cached = DatabaseManager.shared.fetchUpcomingTitles()
            DispatchQueue.main.async {
                if !cached.isEmpty {
                    self?.titles = cached
                    self?.upcomingTable.reloadData()
                    print("[UpcomingVC] Cache loaded: \(cached.count) items")
                }
            }
        }

        // BƯỚC 2: Gọi API song song — khi về thì ghi đè
        APICaller.shared.getUpcomingMovies { [weak self] result in
            switch result {
            case .success(let titles):
                self?.titles = titles
                DispatchQueue.main.async {
                    self?.upcomingTable.reloadData()
                }
                DispatchQueue.global(qos: .utility).async {
                    DatabaseManager.shared.saveUpcomingTitles(titles)
                }
            case .failure(let error):
                // Cache đã hiển thị từ bước 1 — không cần làm gì thêm
                print("[UpcomingVC] API error (cache đang hiển thị): \(error.localizedDescription)")
            }
        }
    }
}

extension UpcomingViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TitleTableViewCell.identifier, for: indexPath) as? TitleTableViewCell else {
            return UITableViewCell()
        }
        let title = titles[indexPath.row]
        let model = TitleViewModel(
            titleName: title.original_name ?? title.original_title ?? "Unknown",
            posterURL: title.poster_path ?? ""
        )
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }
}
