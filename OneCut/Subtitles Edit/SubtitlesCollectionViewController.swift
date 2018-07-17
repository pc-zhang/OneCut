//
//  SubtitlesCollectionViewController.swift
//  OneCut
//
//  Created by zpc on 2018/7/16.
//  Copyright © 2018年 zpc. All rights reserved.
//

import UIKit
import Speech

/*
 * ViewController.swift
 * Created by Michael Michailidis on 10/04/2015.
 * http://blog.karmadust.com/
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

import UIKit

class DataItem : Equatable {
    
    var indexes: String
    var colour: UIColor
    init(_ indexes: String, _ colour: UIColor = UIColor.clear) {
        self.indexes    = indexes
        self.colour     = colour
    }
    
    static func ==(lhs: DataItem, rhs: DataItem) -> Bool {
        return lhs.indexes == rhs.indexes && lhs.colour == rhs.colour
    }
}

extension UIColor {
    static var kdBrown:UIColor {
        return UIColor(red: 177.0/255.0, green: 88.0/255.0, blue: 39.0/255.0, alpha: 1.0)
    }
    static var kdGreen:UIColor {
        return UIColor(red: 138.0/255.0, green: 149.0/255.0, blue: 86.0/255.0, alpha: 1.0)
    }
    static var kdBlue:UIColor {
        return UIColor(red: 53.0/255.0, green: 102.0/255.0, blue: 149.0/255.0, alpha: 1.0)
    }
}

let colours = [UIColor.kdBrown, UIColor.kdGreen, UIColor.kdBlue]

class SubtitlesCollectionViewController: UIViewController, KDDragAndDropCollectionViewDataSource {
    var subtitles = Subtitles(transcription: SFTranscription())
    
    @IBOutlet weak var firstCollectionView: KDDragAndDropCollectionView!
    @IBOutlet weak var secondCollectionView: KDDragAndDropCollectionView!
    @IBOutlet weak var thirdCollectionView: KDDragAndDropCollectionView!
    
    var data : [[DataItem]] = [[DataItem]]()
    
    var dragAndDropManager : KDDragAndDropManager?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // generate some mock data (change in real world project)
        self.data = (0...2).map({ i in (0...20).map({ j in DataItem("\(String(i)):\(String(j))", colours[i])})})
        
        self.dragAndDropManager = KDDragAndDropManager(
            canvas: self.view,
            collectionViews: [firstCollectionView, secondCollectionView, thirdCollectionView]
        )
        
    }
    
    
    // MARK : UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return data[collectionView.tag].count
    }
    
    // The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! ColorCell
        
        let dataItem = data[collectionView.tag][indexPath.item]
        
        cell.label.text = String(indexPath.item) + "\n\n" + dataItem.indexes
        cell.backgroundColor = dataItem.colour
        
        cell.isHidden = false
        
        if let kdCollectionView = collectionView as? KDDragAndDropCollectionView {
            
            if let draggingPathOfCellBeingDragged = kdCollectionView.draggingPathOfCellBeingDragged {
                
                if draggingPathOfCellBeingDragged.item == indexPath.item {
                    
                    cell.isHidden = true
                    
                }
            }
        }
        
        return cell
    }
    
    // MARK : KDDragAndDropCollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, dataItemForIndexPath indexPath: IndexPath) -> AnyObject {
        return data[collectionView.tag][indexPath.item]
    }
    func collectionView(_ collectionView: UICollectionView, insertDataItem dataItem : AnyObject, atIndexPath indexPath: IndexPath) -> Void {
        
        if let di = dataItem as? DataItem {
            data[collectionView.tag].insert(di, at: indexPath.item)
        }
        
        
    }
    func collectionView(_ collectionView: UICollectionView, deleteDataItemAtIndexPath indexPath : IndexPath) -> Void {
        data[collectionView.tag].remove(at: indexPath.item)
    }
    
    func collectionView(_ collectionView: UICollectionView, moveDataItemFromIndexPath from: IndexPath, toIndexPath to : IndexPath) -> Void {
        
        let fromDataItem: DataItem = data[collectionView.tag][from.item]
        data[collectionView.tag].remove(at: from.item)
        data[collectionView.tag].insert(fromDataItem, at: to.item)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, indexPathForDataItem dataItem: AnyObject) -> IndexPath? {
        
        guard let candidate = dataItem as? DataItem else { return nil }
        
        for (i,item) in data[collectionView.tag].enumerated() {
            if candidate != item { continue }
            return IndexPath(item: i, section: 0)
        }
        
        return nil
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellIsDraggableAtIndexPath indexPath: IndexPath) -> Bool {
        return indexPath.row % 2 == 0
    }
}







//class SubtitlesCollectionViewController: UICollectionViewController, RAReorderableLayoutDelegate, RAReorderableLayoutDataSource {
//
//    var subtitles = Subtitles(transcription: SFTranscription())
//
//    var imagesForSection0: [UIImage] = []
//    var imagesForSection1: [UIImage] = []
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        // Uncomment the following line to preserve selection between presentations
//        // self.clearsSelectionOnViewWillAppear = false
//
//        // Do any additional setup after loading the view.
//        for index in 0..<18 {
//            let name = "Sample\(index).jpg"
//            let image = UIImage(named: name)
//            imagesForSection0.append(image!)
//        }
//        for index in 18..<30 {
//            let name = "Sample\(index).jpg"
//            let image = UIImage(named: name)
//            imagesForSection1.append(image!)
//        }
//    }
//
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        collectionView?.contentInset = UIEdgeInsetsMake(topLayoutGuide.length, 0, 0, 0)
//    }
//
//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//        // Dispose of any resources that can be recreated.
//    }
//
//    /*
//    // MARK: - Navigation
//
//    // In a storyboard-based application, you will often want to do a little preparation before navigation
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        // Get the new view controller using [segue destinationViewController].
//        // Pass the selected object to the new view controller.
//    }
//    */
//
//
//    // RAReorderableLayout delegate datasource
//
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//        let screenWidth = UIScreen.main.bounds.width
//        let threePiecesWidth = floor(screenWidth / 3.0 - ((2.0 / 3) * 2))
//        let twoPiecesWidth = floor(screenWidth / 2.0 - (2.0 / 2))
//        if (indexPath as NSIndexPath).section == 0 {
//            return CGSize(width: threePiecesWidth, height: threePiecesWidth)
//        }else {
//            return CGSize(width: twoPiecesWidth, height: twoPiecesWidth)
//        }
//    }
//
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
//        return 2.0
//    }
//
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
//        return 2.0
//    }
//
//    override func numberOfSections(in collectionView: UICollectionView) -> Int {
//        return 2
//    }
//
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
//        return UIEdgeInsetsMake(0, 0, 2.0, 0)
//    }
//
//    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        if section == 0 {
//            return imagesForSection0.count
//        }else {
//            return imagesForSection1.count
//        }
//    }
//
//    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! SubtitleCollectionViewCell
//
//        if (indexPath as NSIndexPath).section == 0 {
//            cell.imageView.image = imagesForSection0[(indexPath as NSIndexPath).item]
//        }else {
//            cell.imageView.image = imagesForSection1[(indexPath as NSIndexPath).item]
//        }
//        return cell
//    }
//
//    func collectionView(_ collectionView: UICollectionView, allowMoveAt indexPath: IndexPath) -> Bool {
//        if collectionView.numberOfItems(inSection: (indexPath as NSIndexPath).section) <= 1 {
//            return false
//        }
//        return true
//    }
//
//    func collectionView(_ collectionView: UICollectionView, at: IndexPath, willMoveTo toIndexPath: IndexPath) {
//
//    }
//
//    func collectionView(_ collectionView: UICollectionView, at atIndexPath: IndexPath, didMoveTo toIndexPath: IndexPath) {
//        var photo: UIImage
//        if (atIndexPath as NSIndexPath).section == 0 {
//            photo = imagesForSection0.remove(at: (atIndexPath as NSIndexPath).item)
//        }else {
//            photo = imagesForSection1.remove(at: (atIndexPath as NSIndexPath).item)
//        }
//
//        if (toIndexPath as NSIndexPath).section == 0 {
//            imagesForSection0.insert(photo, at: (toIndexPath as NSIndexPath).item)
//        }else {
//            imagesForSection1.insert(photo, at: (toIndexPath as NSIndexPath).item)
//        }
//    }
//
//    func scrollTrigerEdgeInsetsInCollectionView(_ collectionView: UICollectionView) -> UIEdgeInsets {
//        return UIEdgeInsetsMake(100.0, 100.0, 100.0, 100.0)
//    }
//
//    func collectionView(_ collectionView: UICollectionView, reorderingItemAlphaInSection section: Int) -> CGFloat {
//        if section == 0 {
//            return 0
//        }else {
//            return 0.3
//        }
//    }
//
//    func scrollTrigerPaddingInCollectionView(_ collectionView: UICollectionView) -> UIEdgeInsets {
//        return UIEdgeInsetsMake(collectionView.contentInset.top, 0, collectionView.contentInset.bottom, 0)
//    }
//
////    override func numberOfSections(in collectionView: UICollectionView) -> Int {
////        // #warning Incomplete implementation, return the number of sections
////        return 1
////    }
////
////
////    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
////        // #warning Incomplete implementation, return the number of items
////        return subtitles.segments.count
////    }
////
////    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
////        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
////
////        let row = indexPath.row
////
////        // Configure the cell...
////        guard let subtitleSegmentCell = cell as? SubtitleCollectionViewCell else {
////            return cell
////        }
////
////        let segment = subtitles.segments[row]
//////        subtitleSegmentCell.timeTextField.text = "\(segment.timestamp),\(segment.duration)"
//////        subtitleSegmentCell.subtitleTextField.text = "\(segment.substring)"
////
////        return subtitleSegmentCell
////    }
//
//    // MARK: UICollectionViewDelegate
//
//    /*
//    // Uncomment this method to specify if the specified item should be highlighted during tracking
//    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
//        return true
//    }
//    */
//
//    /*
//    // Uncomment this method to specify if the specified item should be selected
//    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
//        return true
//    }
//    */
//
//    /*
//    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
//    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
//        return false
//    }
//
//    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
//        return false
//    }
//
//    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
//
//    }
//    */
//
//}
