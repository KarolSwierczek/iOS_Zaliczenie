//
//  MasterViewController.swift
//  zaliczenie
//
//  Created by kprzystalski on 25/12/2019.
//  Copyright © 2019 kprzystalski. All rights reserved.
//

import UIKit
import CoreData

class MasterViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    struct Constants {
        static let id = "id"
        static let product = "product"
        static let description = "description"
        static let image = "image"
        static let location_lat = "location_lat"
        static let location_long = "location_long"
        static let serverUrl: String = "https://my-json-server.typicode.com/mark-kebo/iosUJZaliczenie/products" //kolega hostuje serwer z jsonemn
    }


    var detailViewController: DetailViewController? = nil
    var managedObjectContext: NSManagedObjectContext? = nil

    var appDelegate: AppDelegate? = nil
    
    var productsEntity: NSEntityDescription? = nil
    
    var _fetchedResultsController: NSFetchedResultsController<Product>? = nil
        

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = editButtonItem


        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        self.appDelegate = UIApplication.shared.delegate as? AppDelegate
        
        self.managedObjectContext = appDelegate?.persistentContainer.viewContext
            
        self.productsEntity = NSEntityDescription.entity(forEntityName: "Product", in: self.managedObjectContext!)
        parseJson()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    func parseJson() {
        let url = URL(string: Constants.serverUrl)
        let request = URLRequest(url: url!)
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request, completionHandler: { (data, response, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            guard data != nil else {
                print("No data")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: [])
                if let object = json as? [String:Any] {
                    print(object)
                } else if let object = json as? [Any], let productsEntity = self.productsEntity {

                    for element in object as! [Dictionary<String,AnyObject>] {
                        let id = element[Constants.id] as? Int
                        let productText = element[Constants.product] as? String
                        let desc = element[Constants.description] as? String
                        let image = element[Constants.image] as? String
                        let locationLat = element[Constants.location_lat] as? String
                        let locationLong = element[Constants.location_long] as? String

                        let product = NSManagedObject(entity: productsEntity, insertInto: self.managedObjectContext)
                        product.setValue(id, forKey: Constants.id)
                        product.setValue(productText, forKey: Constants.product)
                        product.setValue(desc, forKey: Constants.description)
                        product.setValue(image, forKey: Constants.image)
                        product.setValue(locationLat, forKey: Constants.location_lat)
                        product.setValue(locationLong, forKey: Constants.location_long)
                    }
                    try self.managedObjectContext?.save()
                } else {
                    print("JSON is not valid")
                }
            } catch {
                print("Serialization JSON error")
            }
            
        })
        task.resume()
    }


    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
            let object = fetchedResultsController.object(at: indexPath)
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.detailItem = object
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
                detailViewController = controller
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let event = fetchedResultsController.object(at: indexPath)
        configureCell(cell, withEvent: event)
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let context = fetchedResultsController.managedObjectContext
            context.delete(fetchedResultsController.object(at: indexPath))
                
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    func configureCell(_ cell: UITableViewCell, withEvent product: Product) {
        cell.textLabel?.text = product.product
    }

    // MARK: - Fetched results controller

    var fetchedResultsController: NSFetchedResultsController<Product> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
                
        fetchRequest.fetchBatchSize = 20
        
        let sortDescriptor = NSSortDescriptor(key: Constants.description, ascending: false)
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: nil, cacheName: "Master")
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
             let nserror = error as NSError
             fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        return _fetchedResultsController!
    }    

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
            case .insert:
                tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
            case .delete:
                tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
            default:
                return
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
            case .insert:
                tableView.insertRows(at: [newIndexPath!], with: .fade)
            case .delete:
                tableView.deleteRows(at: [indexPath!], with: .fade)
            case .update:
                configureCell(tableView.cellForRow(at: indexPath!)!, withEvent: anObject as! Product)
            case .move:
                configureCell(tableView.cellForRow(at: indexPath!)!, withEvent: anObject as! Product)
                tableView.moveRow(at: indexPath!, to: newIndexPath!)
            default:
                return
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }

}
