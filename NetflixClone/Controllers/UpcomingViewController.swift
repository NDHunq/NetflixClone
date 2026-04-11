//
//  UpcomingViewController.swift
//  NetflixClone
//
//  Created by Nguyen Duy Hung on 24/3/26.
//

import UIKit

class UpcomingViewController: UIViewController {
    
    private let pageSize = 30
    private var currentOffset = 0
    private var isLoading = false
    private var hasMore = true
    
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
        
        fetchInitialData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        upcomingTable.frame = view.bounds
    }
    
    private func fetchInitialData() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let cachedTitles = DatabaseManager.shared.fetchUpcomingTitles(limit: self.pageSize, offset: 0)
            DispatchQueue.main.async {
                if !cachedTitles.isEmpty && self.titles.isEmpty {
                    self.titles = cachedTitles
                    self.currentOffset = cachedTitles.count
                    self.upcomingTable.reloadData()
                    print("[UpcomingVC] Đã load \(cachedTitles.count) items từ SQLite Cache")
                }
            }
        }
        
        APICaller.shared.getHomeUpcomingMovies { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let apiTitles):
                DispatchQueue.global(qos: .utility).async {
                    DatabaseManager.shared.saveUpcomingTitles(apiTitles)
                }
                
                DispatchQueue.main.async {
                    self.titles = apiTitles
                    self.currentOffset = apiTitles.count
                    self.hasMore = true
                    self.upcomingTable.reloadData()
                    print("[UpcomingVC] Đã load \(apiTitles.count) items từ API và cập nhật UI")
                }
                
            case .failure(let error):
                print("[UpcomingVC] API error: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadNextPage() {
        guard !isLoading, hasMore else { return }
        isLoading = true
        let offset = currentOffset
        let limit = pageSize
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let newTitles = DatabaseManager.shared.fetchUpcomingTitles(limit: limit, offset: offset)
            DispatchQueue.main.async {
                self.isLoading = false
                if newTitles.isEmpty {
                    self.hasMore = false
                    print("[UpcomingVC] Đã load hết tất cả records")
                    return
                }
                if newTitles.count < self.pageSize {
                    self.hasMore = false
                }
                let startIndex = self.titles.count
                self.titles.append(contentsOf: newTitles)
                self.currentOffset += newTitles.count
                
                let newIndexPaths = (startIndex..<self.titles.count).map {
                    IndexPath(row: $0, section: 0)
                }
                
                self.upcomingTable.insertRows(at: newIndexPaths, with: .none)
                print("[UpcomingVC] Loaded \(newTitles.count) items (offset: \(offset)), total: \(self.titles.count)")
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
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let triggerRow = titles.count - 10
        if indexPath.row >= triggerRow {
            loadNextPage()
        }
    }
}
