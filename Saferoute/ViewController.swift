//
//  ViewController.swift
//  Saferoute
//
//  Created by Tony Li on 6/21/16.
//  Copyright © 2016 Tony Li. All rights reserved.
//

import UIKit
import ArcGIS

let kBasemapLayerName = "Basemap Tiled Layer"

class ViewController: UIViewController, AGSMapViewLayerDelegate, UIAlertViewDelegate, UISearchBarDelegate, AGSLocatorDelegate, AGSFeatureLayerQueryDelegate {
    @IBOutlet weak var mapView: AGSMapView!
    
    var graphicLayer:AGSGraphicsLayer!
    var locator:AGSLocator!
    var calloutTemplate:AGSCalloutTemplate!
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //Add a basemap tiled layer
        let url = NSURL(string: "http://services.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer")
        let tiledLayer = AGSTiledMapServiceLayer(URL: url)
        self.mapView.addMapLayer(tiledLayer, withName: "Basemap Tiled Layer")
        
        
        //Set the map view's layer delegate
        self.mapView.layerDelegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //MARK: map view layer delegate methods
    
    func mapViewDidLoad(mapView: AGSMapView!) {
        //do something now that the map is loaded
        //for example, show the current location on the map
        mapView.locationDisplay.startDataSource()
       
    }
    
    @IBAction func basemapChanged(sender: UISegmentedControl) {
        
        var basemapURL:NSURL!
        
        switch sender.selectedSegmentIndex {
        case 0:  //gray
            basemapURL = NSURL(string: "http://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer")
        case 1:  //oceans
            basemapURL = NSURL(string: "http://services.arcgisonline.com/ArcGIS/rest/services/Ocean_Basemap/MapServer")
        case 2:  //nat geo
            basemapURL = NSURL(string: "http://services.arcgisonline.com/ArcGIS/rest/services/NatGeo_World_Map/MapServer")
        case 3:  //topo
            basemapURL = NSURL(string: "http://services.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer")
        default:  //sat
            basemapURL = NSURL(string: "http://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer")
        }
        self.mapView.removeMapLayerWithName(kBasemapLayerName)
        
        //add new Layer
        let newBasemapLayer = AGSTiledMapServiceLayer(URL: basemapURL)
        self.mapView.insertMapLayer(newBasemapLayer, withName: kBasemapLayerName, atIndex: 0);
    }
    
    @IBAction func showStreetLights(sender: AnyObject) {
        //CLOUD DATA
        let testPoint = AGSPoint(fromDecimalDegreesString: "34.0522 N, 118.2437 W", withSpatialReference: mapView.spatialReference)
        mapView.zoomToScale(10000, withCenterPoint: testPoint, animated: true)
        
        let featureLayerURL = NSURL(string: "http://services1.arcgis.com/p84PN4WZvOWzi2j2/arcgis/rest/services/StreetLights/FeatureServer/0")
        let featureLayer = AGSFeatureLayer(URL: featureLayerURL, mode: .OnDemand)
        self.mapView.addMapLayer(featureLayer, withName: "Street Lights")
        
        //SYMBOLOGY
        /*let featureSymbol = AGSSimpleMarkerSymbol(color:UIColor(red: 0, green: 0.46, blue: 0.68, alpha: 1))
        featureSymbol.size = CGSizeMake(7, 7)
        featureSymbol.style = .Circle
        featureSymbol.outline = nil
        featureLayer.renderer = AGSSimpleRenderer(symbol: featureSymbol)*/
        
        

    }
    
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        //Hide the keyboard
        searchBar.resignFirstResponder()
        
        if self.graphicLayer == nil {
            //Add a graphics layer to the map. This layer will hold geocoding results
            self.graphicLayer = AGSGraphicsLayer()
            self.mapView.addMapLayer(self.graphicLayer, withName:"Results")
            
            //Assign a simple renderer to the layer to display results as pushpins
            let pushpin = AGSPictureMarkerSymbol(imageNamed: "BluePushpin.png")
            pushpin.offset = CGPointMake(9, 16)
            pushpin.leaderPoint = CGPointMake(-9, 11)
            let renderer = AGSSimpleRenderer(symbol: pushpin)
            self.graphicLayer.renderer = renderer
        }
        else {
            //Clear out previous results if we already have a graphics layer
            self.graphicLayer.removeAllGraphics()
        }
        
        
        if self.locator == nil {
            //Create the AGSLocator pointing to the geocode service on ArcGIS Online
            //Set the delegate so that we are informed through AGSLocatorDelegate methods
            let url = NSURL(string: "http://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer")
            self.locator = AGSLocator(URL: url)
            self.locator.delegate = self
        }
        
        //Set the parameters
        let params = AGSLocatorFindParameters()
        params.text = searchBar.text
        params.outFields = ["*"]
        params.outSpatialReference = self.mapView.spatialReference
        params.location = AGSPoint(x: 0, y: 0, spatialReference: nil)
        
        //Kick off the geocoding operation
        //This will invoke the geocode service on a background thread
        self.locator.findWithParameters(params)
    }
    
    //MARK: AGSLocator delegate methods
    
    func locator(locator: AGSLocator!, operation op: NSOperation!, didFind results: [AnyObject]!) {
        if results == nil || results.count == 0 {
            //show alert if we didn't get results
            UIAlertView(title: "No Results", message: "No Results Found", delegate: nil, cancelButtonTitle: "OK").show()
        }
        else {
            //Create a callout template if we haven't done so already
            if self.calloutTemplate == nil {
                self.calloutTemplate = AGSCalloutTemplate()
                self.calloutTemplate.titleTemplate = "${Match_addr}"
                self.calloutTemplate.detailTemplate = "${DisplayY}\u{00b0} ${DisplayX}\u{00b0}"
                
                //Assign the callout template to the layer so that all graphics within this layer
                //display their information in the callout in the same manner
                self.graphicLayer.calloutDelegate = self.calloutTemplate
            }
            
            //Add a graphic for each result
            for result in results as! [AGSLocatorFindResult] {
                self.graphicLayer.addGraphic(result.graphic)
            }
            
            //Zoom in to the results
            let extent = self.graphicLayer.fullEnvelope.mutableCopy() as! AGSMutableEnvelope
            extent.expandByFactor(1.5)
            self.mapView.zoomToEnvelope(extent, animated: true)
        }
    }
    
    func locator(locator: AGSLocator!, operation op: NSOperation!, didFailLocationsForAddress error: NSError!) {
        UIAlertView(title: "Locator Failed", message: error.localizedDescription, delegate: nil, cancelButtonTitle: "OK").show()
    }
    
    func featureLayer(featureLayer: AGSFeatureLayer!, operation op: NSOperation!, didSelectFeaturesWithFeatureSet featureSet: AGSFeatureSet!) {
        //ZOOM TO SELECTED DATA
        var env:AGSMutableEnvelope!
        for selectedFeature in featureSet.features as! [AGSGraphic]{
            if env != nil {
                env.unionWithEnvelope(selectedFeature.geometry.envelope)
            }
            else {
                env = selectedFeature.geometry.envelope.mutableCopy() as! AGSMutableEnvelope
            }
        }
        self.mapView.zoomToGeometry(env, withPadding: 20, animated: true)
    }


}
