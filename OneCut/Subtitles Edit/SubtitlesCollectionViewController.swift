//
//  SubtitlesCollectionViewController.swift
//  OneCut
//
//  Created by zpc on 2018/7/16.
//  Copyright © 2018年 zpc. All rights reserved.
//

import UIKit
import Speech


class SubtitlesCollectionViewController: UIViewController, KDDragAndDropCollectionViewDataSource {
    var subtitles = Subtitles(transcription: SFTranscription())
    
    @IBOutlet weak var firstCollectionView: KDDragAndDropCollectionView!
    
    var dragAndDropManager : KDDragAndDropManager?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.dragAndDropManager = KDDragAndDropManager(
            canvas: self.view,
            collectionViews: [firstCollectionView]
        )
        
        if let layout = firstCollectionView?.collectionViewLayout as? CollectionViewShelfLayout {
            layout.sectionCellInset = UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
            firstCollectionView?.register(SubtitleSectionHeaderView.self, forSupplementaryViewOfKind: ShelfElementKindSectionHeader, withReuseIdentifier: "Header")
        }
    }
    
    
    // MARK: UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 2.0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 2.0
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return subtitles.segments.count
    }
    
    // The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! SubtitleCollectionViewCell
        
        cell.label.text = String(indexPath.item) + "\n\n" + subtitles.segments[indexPath.item].substring
        
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
    
    private func createTimeString(time: Double) -> String? {
        var components = DateComponents()
        components.second = Int(max(0.0, time))
        
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        
        return formatter.string(from: components)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
        if let view = view as? SubtitleSectionHeaderView {
            view.label.text = String(subtitles.segments[(indexPath as NSIndexPath).section].timestamp)
            view.label.textColor = .darkGray
        }
        return view
    }
    
    // MARK: KDDragAndDropCollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, dataItemForIndexPath indexPath: IndexPath) -> AnyObject {
        return subtitles.segments[indexPath.item]
    }
    
    func collectionView(_ collectionView: UICollectionView, insertDataItem dataItem : AnyObject, atIndexPath indexPath: IndexPath) -> Void {
        
        if let di = dataItem as? TranscriptionSegment {
            subtitles.segments.insert(di, at: indexPath.item)
        }
        
        
    }
    
    func collectionView(_ collectionView: UICollectionView, deleteDataItemAtIndexPath indexPath : IndexPath) -> Void {
        subtitles.segments.remove(at: indexPath.item)
    }
    
    func collectionView(_ collectionView: UICollectionView, moveDataItemFromIndexPath from: IndexPath, toIndexPath to : IndexPath) -> Void {
        
        let fromDataItem: TranscriptionSegment = subtitles.segments[from.item]
        subtitles.segments.remove(at: from.item)
        subtitles.segments.insert(fromDataItem, at: to.item)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, indexPathForDataItem dataItem: AnyObject) -> IndexPath? {
        
        guard let candidate = dataItem as? TranscriptionSegment else { return nil }
        
        for (i,item) in subtitles.segments.enumerated() {
            if candidate != item { continue }
            return IndexPath(item: i, section: 0)
        }
        
        return nil
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellIsDraggableAtIndexPath indexPath: IndexPath) -> Bool {
        return true
    }
}


class SubtitleCollectionViewCell: UICollectionViewCell {
    var imageView: UIImageView!
    var gradientLayer: CAGradientLayer?
    var hilightedCover: UIView!
    
    @IBOutlet weak var label: UILabel!
    
    override var isHighlighted: Bool {
        didSet {
            hilightedCover.isHidden = !isHighlighted
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        hilightedCover.frame = bounds
        applyGradation(imageView)
    }
    
    private func configure() {
        imageView = UIImageView()
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = UIViewContentMode.scaleAspectFill
        addSubview(imageView)
        
        hilightedCover = UIView()
        hilightedCover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hilightedCover.backgroundColor = UIColor(white: 0, alpha: 0.5)
        hilightedCover.isHidden = true
        addSubview(hilightedCover)
    }
    
    private func applyGradation(_ gradientView: UIView!) {
        gradientLayer?.removeFromSuperlayer()
        gradientLayer = nil
        
        gradientLayer = CAGradientLayer()
        gradientLayer!.frame = gradientView.bounds
        
        let mainColor = UIColor(white: 0, alpha: 0.3).cgColor
        let subColor = UIColor.clear.cgColor
        gradientLayer!.colors = [subColor, mainColor]
        gradientLayer!.locations = [0, 1]
        
        gradientView.layer.addSublayer(gradientLayer!)
    }
}

class SubtitleSectionHeaderView: UICollectionReusableView {
    let label: UILabel = UILabel()
    var indexPath: IndexPath?
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        
        self.indexPath = layoutAttributes.indexPath
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        isUserInteractionEnabled = true
        
        backgroundColor = UIColor.white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        label.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

