//
//  FileChooserViewController.swift
//  ModPlayer
//
//  Created by Andy Qua on 17/11/2019.
//  Copyright © 2019 Andy Qua. All rights reserved.
//

import UIKit

class FileChooserViewController: UITableViewController {
    var webUploader : WebServer!

    var selectedFile : ((URL)->())?

    private let cellReuseIdentifier = "Cell"
    private lazy var dataSource = makeDataSource()

    private var files : [URL] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self,
                           forCellReuseIdentifier: cellReuseIdentifier
        )
        tableView.dataSource = dataSource
        
        refreshFilesList()
        self.update(with: files, animate: false)
    }
    
    func refreshFilesList() {
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: documentPath(), includingPropertiesForKeys: [], options: []) {
            self.files = files
        }
    }
}

// Display Action menu
extension FileChooserViewController {
    @IBAction func addFiles( _ sender : Any ) {
        self.webUploader = WebServer()
        if ( self.webUploader.startServer() ) {
            
            let ac = UIAlertController(title: "Upload started", message: "You can now view and download files by visiting: \(self.webUploader.getServerAddress()) in your browser", preferredStyle: .alert)
            
            ac.addAction(UIAlertAction(title: "Stop", style: .default, handler: { [weak self] (action) in
                guard let `self` = self else { return }
                self.webUploader.stopServer()
                
                self.refreshFilesList()
                self.update(with: self.files, animate: true)

            }))
            
            self.present(ac, animated: true, completion: nil)
        } else {
            showAlert(title: "Webserver failed", message: "Couldn't start the server!")
        }
    }
}

extension FileChooserViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print( "Selected - \(files[indexPath.row])" )
        selectedFile?(files[indexPath.row])
    }
}

private extension FileChooserViewController {
    func makeDataSource() -> UITableViewDiffableDataSource<String, String> {
        let reuseIdentifier = cellReuseIdentifier
        
        return UITableViewDiffableDataSource( tableView: tableView, cellProvider: {  tableView, indexPath, filename in
                let cell = tableView.dequeueReusableCell( withIdentifier: reuseIdentifier, for: indexPath )
                
                cell.textLabel?.text = filename
                return cell
        })
    }

    func update(with list: [URL], animate: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<String, String>()
        snapshot.appendSections(["section1"])
        
        let filenames = files.map { $0.lastPathComponent }
        snapshot.appendItems(filenames, toSection: "section1")
        
        dataSource.apply(snapshot, animatingDifferences: animate)
    }
}
