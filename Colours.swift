//
//  Colours.swift
//  ColoursDemo
//
//  Created by Ben Gordon on 12/27/14.
//  Copyright (c) 2014 Ben Gordon. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
public typealias Color = UIColor
#else
import AppKit
public typealias Color = NSColor
#endif

public extension Color {
    // MARK: - Closure
    typealias TransformBlock = (CGFloat) -> CGFloat
    
    // MARK: - Enums
    enum ColorScheme:Int {
        case analagous = 0, monochromatic, triad, complementary
    }
    
    enum ColorFormulation:Int {
        case rgba = 0, hsba, lab, cmyk
    }
    
    enum ColorDistance:Int {
        case cie76 = 0, cie94, cie2000
    }
    
    enum ColorComparison:Int {
        case darkness = 0, lightness, desaturated, saturated, red, green, blue
    }
    
    
    // MARK: - Color from Hex/RGBA/HSBA/CIE_LAB/CMYK
    convenience init(hex: String) {
        var rgbInt: UInt64 = 0
        let newHex = hex.replacingOccurrences(of: "#", with: "")
        let scanner = Scanner(string: newHex)
        scanner.scanHexInt64(&rgbInt)
        let r: CGFloat = CGFloat((rgbInt & 0xFF0000) >> 16)/255.0
        let g: CGFloat = CGFloat((rgbInt & 0x00FF00) >> 8)/255.0
        let b: CGFloat = CGFloat(rgbInt & 0x0000FF)/255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    convenience init(rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)) {
        self.init(red: rgba.r, green: rgba.g, blue: rgba.b, alpha: rgba.a)
    }
    
    convenience init(hsba: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat)) {
        self.init(hue: hsba.h, saturation: hsba.s, brightness: hsba.b, alpha: hsba.a)
    }
    
    convenience init(CIE_LAB: (l: CGFloat, a: CGFloat, b: CGFloat, alpha: CGFloat)) {
        // Set Up
        var Y = (CIE_LAB.l + 16.0)/116.0
        var X = CIE_LAB.a/500 + Y
        var Z = Y - CIE_LAB.b/200
        
        // Transform XYZ
        let deltaXYZ: TransformBlock = { k in
            return (pow(k, 3.0) > 0.008856) ? pow(k, 3.0) : (k - 4/29.0)/7.787
        }
        X = deltaXYZ(X)*0.95047
        Y = deltaXYZ(Y)*1.000
        Z = deltaXYZ(Z)*1.08883
        
        // Convert XYZ to RGB
        let R = X*3.2406 + (Y * -1.5372) + (Z * -0.4986)
        let G = (X * -0.9689) + Y*1.8758 + Z*0.0415
        let B = X*0.0557 + (Y * -0.2040) + Z*1.0570
        let deltaRGB: TransformBlock = { k in
            return (k > 0.0031308) ? 1.055 * (pow(k, (1/2.4))) - 0.055 : k * 12.92
        }
        
        self.init(rgba: (deltaRGB(R), deltaRGB(G), deltaRGB(B), CIE_LAB.alpha))
    }
    
    convenience init(cmyk: (c: CGFloat, m: CGFloat, y: CGFloat, k: CGFloat)) {
        let cmyTransform: TransformBlock = { x in
            return x * (1 - cmyk.k) + cmyk.k
        }
        let C = cmyTransform(cmyk.c)
        let M = cmyTransform(cmyk.m)
        let Y = cmyTransform(cmyk.y)
        self.init(rgba: (1 - C, 1 - M, 1 - Y, 1.0))
    }
    
    
    // MARK: - Color to Hex/RGBA/HSBA/CIE_LAB/CMYK
    func hexString() -> String {
        let rgbaT = rgba()
        let r: Int = Int(rgbaT.r * 255)
        let g: Int = Int(rgbaT.g * 255)
        let b: Int = Int(rgbaT.b * 255)
        let red = NSString(format: "%02x", r)
        let green = NSString(format: "%02x", g)
        let blue = NSString(format: "%02x", b)
        return "#\(red)\(green)\(blue)"
    }
    
    func rgba() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        guard let components = self.cgColor.components else {
            //FIXME: Fallback to black
            return (0, 0, 0, 1)
        }
        let numberOfComponents = self.cgColor.numberOfComponents

        switch numberOfComponents {
        case 4:
            return (components[0], components[1], components[2], components[3])
        case 2:
            return (components[0], components[0], components[0], components[1])
        default:
            // FIXME: Fallback to black
            return (0, 0, 0, 1)
        }
    }
    
    func hsba() -> (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        if self.responds(to: #selector(Color.getHue(_:saturation:brightness:alpha:))) && self.cgColor.numberOfComponents == 4 {
            self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        }
        
        return (h, s, b, a)
    }
    
    func CIE_LAB() -> (l: CGFloat, a: CGFloat, b: CGFloat, alpha: CGFloat) {
        // Get XYZ
        let xyzT = xyz()
        let x = xyzT.x/95.047
        let y = xyzT.y/100.000
        let z = xyzT.z/108.883
        
        // Transfrom XYZ to L*a*b
        let deltaF: TransformBlock = { f in
            let transformation = (f > pow((6.0/29.0), 3.0)) ? pow(f, 1.0/3.0) : (1/3) * pow((29.0/6.0), 2.0) * f + 4/29.0
            
            return (transformation)
        }
        let X = deltaF(x)
        let Y = deltaF(y)
        let Z = deltaF(z)
        let L = 116*Y - 16
        let a = 500 * (X - Y)
        let b = 200 * (Y - Z)
        
        return (L, a, b, xyzT.alpha)
    }
    
    func xyz() -> (x: CGFloat, y: CGFloat, z: CGFloat, alpha: CGFloat) {
        // Get RGBA values
        let rgbaT = rgba()

        // Transfrom values to XYZ
        let deltaR: TransformBlock = { R in
            return (R > 0.04045) ? pow((R + 0.055)/1.055, 2.40) : (R/12.92)
        }
        let R = deltaR(rgbaT.r)
        let G = deltaR(rgbaT.g)
        let B = deltaR(rgbaT.b)
        let X = (R*41.24 + G*35.76 + B*18.05)
        let Y = (R*21.26 + G*71.52 + B*7.22)
        let Z = (R*1.93 + G*11.92 + B*95.05)
        
        return (X, Y, Z, rgbaT.a)
    }
    
    func cmyk() -> (c: CGFloat, m: CGFloat, y: CGFloat, k: CGFloat) {
        // Convert RGB to CMY
        let rgbaT = rgba()
        let C = 1 - rgbaT.r
        let M = 1 - rgbaT.g
        let Y = 1 - rgbaT.b
        
        // Find K
        let K = min(1, min(C, min(Y, M)))
        if (K == 1) {
            return (0, 0, 0, 1)
        }
        
        // Convert cmyk
        let newCMYK: TransformBlock = { x in
            return (x - K)/(1 - K)
        }
        return (newCMYK(C), newCMYK(M), newCMYK(Y), K)
    }
    
    
    // MARK: - Color Components
    func red() -> CGFloat {
        return rgba().r
    }
    
    func green() -> CGFloat {
        return rgba().g
    }
    
    func blue() -> CGFloat {
        return rgba().b
    }
    
    func alpha() -> CGFloat {
        return rgba().a
    }
    
    func hue() -> CGFloat {
        return hsba().h
    }
    
    func saturation() -> CGFloat {
        return hsba().s
    }
    
    func brightness() -> CGFloat {
        return hsba().b
    }
    
    func CIE_Lightness() -> CGFloat {
        return CIE_LAB().l
    }
    
    func CIE_a() -> CGFloat {
        return CIE_LAB().a
    }
    
    func CIE_b() -> CGFloat {
        return CIE_LAB().b
    }
    
    func cyan() -> CGFloat {
        return cmyk().c
    }
    
    func magenta() -> CGFloat {
        return cmyk().m
    }
    
    func yellow() -> CGFloat {
        return cmyk().y
    }
    
    func keyBlack() -> CGFloat {
        return cmyk().k
    }
    
    
    // MARK: - Lighten/Darken Color
    func lightenedColor(_ percentage: CGFloat) -> Color {
        return modifiedColor(percentage + 1.0)
    }
    
    func darkenedColor(_ percentage: CGFloat) -> Color {
        return modifiedColor(1.0 - percentage)
    }
    
    fileprivate func modifiedColor(_ percentage: CGFloat) -> Color {
        let hsbaT = hsba()
        return Color(hsba: (hsbaT.h, hsbaT.s, hsbaT.b * percentage, hsbaT.a))
    }
    
    
    // MARK: - Contrasting Color
    func blackOrWhiteContrastingColor() -> Color {
        let rgbaT = rgba()
        let value = 1 - ((0.299 * rgbaT.r) + (0.587 * rgbaT.g) + (0.114 * rgbaT.b));
        return value < 0.5 ? Color.black : Color.white
    }
    
    
    // MARK: - Complementary Color
    func complementaryColor() -> Color {
        let hsbaT = hsba()
        let newH = Color.addDegree(180.0, staticDegree: hsbaT.h*360.0)
        return Color(hsba: (newH, hsbaT.s, hsbaT.b, hsbaT.a))
    }
    
    
    // MARK: - Color Scheme
    func colorScheme(_ type: ColorScheme) -> [Color] {
        switch (type) {
        case .analagous:
            return Color.analgousColors(self.hsba())
        case .monochromatic:
            return Color.monochromaticColors(self.hsba())
        case .triad:
            return Color.triadColors(self.hsba())
        default:
            return Color.complementaryColors(self.hsba())
        }
    }
    
    fileprivate class func analgousColors(_ hsbaT: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat)) -> [Color] {
        return [Color(hsba: (self.addDegree(30, staticDegree: hsbaT.h*360)/360.0, hsbaT.s-0.05, hsbaT.b-0.1, hsbaT.a)),
                Color(hsba: (self.addDegree(15, staticDegree: hsbaT.h*360)/360.0, hsbaT.s-0.05, hsbaT.b-0.05, hsbaT.a)),
                Color(hsba: (self.addDegree(-15, staticDegree: hsbaT.h*360)/360.0, hsbaT.s-0.05, hsbaT.b-0.05, hsbaT.a)),
                Color(hsba: (self.addDegree(-30, staticDegree: hsbaT.h*360)/360.0, hsbaT.s-0.05, hsbaT.b-0.1, hsbaT.a))]
    }
    
    fileprivate class func monochromaticColors(_ hsbaT: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat)) -> [Color] {
        return [Color(hsba: (hsbaT.h, hsbaT.s/2, hsbaT.b/3, hsbaT.a)),
                Color(hsba: (hsbaT.h, hsbaT.s, hsbaT.b/2, hsbaT.a)),
                Color(hsba: (hsbaT.h, hsbaT.s/3, 2*hsbaT.b/3, hsbaT.a)),
                Color(hsba: (hsbaT.h, hsbaT.s, 4*hsbaT.b/5, hsbaT.a))]
    }
    
    fileprivate class func triadColors(_ hsbaT: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat)) -> [Color] {
        return [Color(hsba: (self.addDegree(120, staticDegree: hsbaT.h*360)/360.0, 2*hsbaT.s/3, hsbaT.b-0.05, hsbaT.a)),
                Color(hsba: (self.addDegree(120, staticDegree: hsbaT.h*360)/360.0, hsbaT.s, hsbaT.b, hsbaT.a)),
                Color(hsba: (self.addDegree(240, staticDegree: hsbaT.h*360)/360.0, hsbaT.s, hsbaT.b, hsbaT.a)),
                Color(hsba: (self.addDegree(240, staticDegree: hsbaT.h*360)/360.0, 2*hsbaT.s/3, hsbaT.b-0.05, hsbaT.a))]
    }
    
    fileprivate class func complementaryColors(_ hsbaT: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat)) -> [Color] {
        return [Color(hsba: (hsbaT.h, hsbaT.s, 4*hsbaT.b/5, hsbaT.a)),
                Color(hsba: (hsbaT.h, 5*hsbaT.s/7, hsbaT.b, hsbaT.a)),
                Color(hsba: (self.addDegree(180, staticDegree: hsbaT.h*360)/360.0, hsbaT.s, hsbaT.b, hsbaT.a)),
                Color(hsba: (self.addDegree(180, staticDegree: hsbaT.h*360)/360.0, 5*hsbaT.s/7, hsbaT.b, hsbaT.a))]
    }
    
    
    // MARK: - Predefined Colors
    // MARK: -
    // MARK: System Colors
    class var infoBlue: Color
    {
        return self.colorWith(47, G:112, B:225, A:1.0)
    }
    
    class var success: Color
    {
        return self.colorWith(83, G:215, B:106, A:1.0)
    }
    
    class var warning: Color
    {
        return self.colorWith(221, G:170, B:59, A:1.0)
    }
    
    class var danger: Color
    {
        return self.colorWith(229, G:0, B:15, A:1.0)
    }
    
    
    // MARK: Whites
    class var antiqueWhite: Color
    {
        return self.colorWith(250, G:235, B:215, A:1.0)
    }
    
    class var oldLace: Color
    {
        return self.colorWith(253, G:245, B:230, A:1.0)
    }
    
    class var ivory: Color
    {
        return self.colorWith(255, G:255, B:240, A:1.0)
    }
    
    class var seashell: Color
    {
        return self.colorWith(255, G:245, B:238, A:1.0)
    }
    
    class var ghostWhite: Color
    {
        return self.colorWith(248, G:248, B:255, A:1.0)
    }
    
    class var snow: Color
    {
        return self.colorWith(255, G:250, B:250, A:1.0)
    }
    
    class var linen: Color
    {
        return self.colorWith(250, G:240, B:230, A:1.0)
    }
    
    
    // MARK: Grays
    class var black25Percent: Color
    {
        return Color(white:0.25, alpha:1.0)
    }
    
    class var black50Percent: Color
    {
        return Color(white:0.5,  alpha:1.0)
    }
    
    class var black75Percent: Color
    {
        return Color(white:0.75, alpha:1.0)
    }
    
    class var warmGray: Color
    {
        return self.colorWith(133, G:117, B:112, A:1.0)
    }
    
    class var coolGray: Color
    {
        return self.colorWith(118, G:122, B:133, A:1.0)
    }
    
    class var charcoal: Color
    {
        return self.colorWith(34, G:34, B:34, A:1.0)
    }
    
    
    // MARK: Blues
    class var teal: Color
    {
        return self.colorWith(28, G:160, B:170, A:1.0)
    }
    
    class var steelBlue: Color
    {
        return self.colorWith(103, G:153, B:170, A:1.0)
    }
    
    class var robinEgg: Color
    {
        return self.colorWith(141, G:218, B:247, A:1.0)
    }
    
    class var pastelBlue: Color
    {
        return self.colorWith(99, G:161, B:247, A:1.0)
    }
    
    class var turquoise: Color
    {
        return self.colorWith(112, G:219, B:219, A:1.0)
    }
    
    class var skyBlue: Color
    {
        return self.colorWith(0, G:178, B:238, A:1.0)
    }
    
    class var indigo: Color
    {
        return self.colorWith(13, G:79, B:139, A:1.0)
    }
    
    class var denim: Color
    {
        return self.colorWith(67, G:114, B:170, A:1.0)
    }
    
    class var blueberry: Color
    {
        return self.colorWith(89, G:113, B:173, A:1.0)
    }
    
    class var cornflower: Color
    {
        return self.colorWith(100, G:149, B:237, A:1.0)
    }
    
    class var babyBlue: Color
    {
        return self.colorWith(190, G:220, B:230, A:1.0)
    }
    
    class var midnightBlue: Color
    {
        return self.colorWith(13, G:26, B:35, A:1.0)
    }
    
    class var fadedBlue: Color
    {
        return self.colorWith(23, G:137, B:155, A:1.0)
    }
    
    class var iceberg: Color
    {
        return self.colorWith(200, G:213, B:219, A:1.0)
    }
    
    class var wave: Color
    {
        return self.colorWith(102, G:169, B:251, A:1.0)
    }
    
    
    // MARK: Greens
    class var emerald: Color
    {
        return self.colorWith(1, G:152, B:117, A:1.0)
    }
    
    class var grass: Color
    {
        return self.colorWith(99, G:214, B:74, A:1.0)
    }
    
    class var pastelGreen: Color
    {
        return self.colorWith(126, G:242, B:124, A:1.0)
    }
    
    class var seafoam: Color
    {
        return self.colorWith(77, G:226, B:140, A:1.0)
    }
    
    class var paleGreen: Color
    {
        return self.colorWith(176, G:226, B:172, A:1.0)
    }
    
    class var cactusGreen: Color
    {
        return self.colorWith(99, G:111, B:87, A:1.0)
    }
    
    class var chartreuse: Color
    {
        return self.colorWith(69, G:139, B:0, A:1.0)
    }
    
    class var hollyGreen: Color
    {
        return self.colorWith(32, G:87, B:14, A:1.0)
    }
    
    class var olive: Color
    {
        return self.colorWith(91, G:114, B:34, A:1.0)
    }
    
    class var oliveDrab: Color
    {
        return self.colorWith(107, G:142, B:35, A:1.0)
    }
    
    class var moneyGreen: Color
    {
        return self.colorWith(134, G:198, B:124, A:1.0)
    }
    
    class var honeydew: Color
    {
        return self.colorWith(216, G:255, B:231, A:1.0)
    }
    
    class var lime: Color
    {
        return self.colorWith(56, G:237, B:56, A:1.0)
    }
    
    class var cardTable: Color
    {
        return self.colorWith(87, G:121, B:107, A:1.0)
    }
    
    
    // MARK: Reds
    class var salmon: Color
    {
        return self.colorWith(233, G:87, B:95, A:1.0)
    }
    
    class var brickRed: Color
    {
        return self.colorWith(151, G:27, B:16, A:1.0)
    }
    
    class var easterPink: Color
    {
        return self.colorWith(241, G:167, B:162, A:1.0)
    }
    
    class var grapefruit: Color
    {
        return self.colorWith(228, G:31, B:54, A:1.0)
    }
    
    class var pink: Color
    {
        return self.colorWith(255, G:95, B:154, A:1.0)
    }
    
    class var indianRed: Color
    {
        return self.colorWith(205, G:92, B:92, A:1.0)
    }
    
    class var strawberry: Color
    {
        return self.colorWith(190, G:38, B:37, A:1.0)
    }
    
    class var coral: Color
    {
        return self.colorWith(240, G:128, B:128, A:1.0)
    }
    
    class var maroon: Color
    {
        return self.colorWith(80, G:4, B:28, A:1.0)
    }
    
    class var watermelon: Color
    {
        return self.colorWith(242, G:71, B:63, A:1.0)
    }
    
    class var tomato: Color
    {
        return self.colorWith(255, G:99, B:71, A:1.0)
    }
    
    class var pinkLipstick: Color
    {
        return self.colorWith(255, G:105, B:180, A:1.0)
    }
    
    class var paleRose: Color
    {
        return self.colorWith(255, G:228, B:225, A:1.0)
    }
    
    class var crimson: Color
    {
        return self.colorWith(187, G:18, B:36, A:1.0)
    }
    
    
    // MARK: Purples
    class var eggplant: Color
    {
        return self.colorWith(105, G:5, B:98, A:1.0)
    }
    
    class var pastelPurple: Color
    {
        return self.colorWith(207, G:100, B:235, A:1.0)
    }
    
    class var palePurple: Color
    {
        return self.colorWith(229, G:180, B:235, A:1.0)
    }
    
    class var coolPurple: Color
    {
        return self.colorWith(140, G:93, B:228, A:1.0)
    }
    
    class var violet: Color
    {
        return self.colorWith(191, G:95, B:255, A:1.0)
    }
    
    class var plum: Color
    {
        return self.colorWith(139, G:102, B:139, A:1.0)
    }
    
    class var lavender: Color
    {
        return self.colorWith(204, G:153, B:204, A:1.0)
    }
    
    class var raspberry: Color
    {
        return self.colorWith(135, G:38, B:87, A:1.0)
    }
    
    class var fuschia: Color
    {
        return self.colorWith(255, G:20, B:147, A:1.0)
    }
    
    class var grape: Color
    {
        return self.colorWith(54, G:11, B:88, A:1.0)
    }
    
    class var periwinkle: Color
    {
        return self.colorWith(135, G:159, B:237, A:1.0)
    }
    
    class var orchid: Color
    {
        return self.colorWith(218, G:112, B:214, A:1.0)
    }
    
    
    // MARK: Yellows
    class var goldenrod: Color
    {
        return self.colorWith(215, G:170, B:51, A:1.0)
    }
    
    class var yellowGreen: Color
    {
        return self.colorWith(192, G:242, B:39, A:1.0)
    }
    
    class var banana: Color
    {
        return self.colorWith(229, G:227, B:58, A:1.0)
    }
    
    class var mustard: Color
    {
        return self.colorWith(205, G:171, B:45, A:1.0)
    }
    
    class var buttermilk: Color
    {
        return self.colorWith(254, G:241, B:181, A:1.0)
    }
    
    class var gold: Color
    {
        return self.colorWith(139, G:117, B:18, A:1.0)
    }
    
    class var cream: Color
    {
        return self.colorWith(240, G:226, B:187, A:1.0)
    }
    
    class var lightCream: Color
    {
        return self.colorWith(240, G:238, B:215, A:1.0)
    }
    
    class var wheat: Color
    {
        return self.colorWith(240, G:238, B:215, A:1.0)
    }
    
    class var beige: Color
    {
        return self.colorWith(245, G:245, B:220, A:1.0)
    }
    
    
    // MARK: Oranges
    class var peach: Color
    {
        return self.colorWith(242, G:187, B:97, A:1.0)
    }
    
    class var burntOrange: Color
    {
        return self.colorWith(184, G:102, B:37, A:1.0)
    }
    
    class var pastelOrange: Color
    {
        return self.colorWith(248, G:197, B:143, A:1.0)
    }
    
    class var cantaloupe: Color
    {
        return self.colorWith(250, G:154, B:79, A:1.0)
    }
    
    class var carrot: Color
    {
        return self.colorWith(237, G:145, B:33, A:1.0)
    }
    
    class var mandarin: Color
    {
        return self.colorWith(247, G:145, B:55, A:1.0)
    }
    
    
    // MARK: Browns
    class var chiliPowder: Color
    {
        return self.colorWith(199, G:63, B:23, A:1.0)
    }
    
    class var burntSienna: Color
    {
        return self.colorWith(138, G:54, B:15, A:1.0)
    }
    
    class var chocolate: Color
    {
        return self.colorWith(94, G:38, B:5, A:1.0)
    }
    
    class var coffee: Color
    {
        return self.colorWith(141, G:60, B:15, A:1.0)
    }
    
    class var cinnamon: Color
    {
        return self.colorWith(123, G:63, B:9, A:1.0)
    }
    
    class var almond: Color
    {
        return self.colorWith(196, G:142, B:72, A:1.0)
    }
    
    class var eggshell: Color
    {
        return self.colorWith(252, G:230, B:201, A:1.0)
    }
    
    class var sand: Color
    {
        return self.colorWith(222, G:182, B:151, A:1.0)
    }
    
    class var mud: Color
    {
        return self.colorWith(70, G:45, B:29, A:1.0)
    }
    
    class var sienna: Color
    {
        return self.colorWith(160, G:82, B:45, A:1.0)
    }
    
    class var dust: Color
    {
        return self.colorWith(236, G:214, B:197, A:1.0)
    }

    
    // MARK: - Private Helpers
    fileprivate class func colorWith(_ R: CGFloat, G: CGFloat, B: CGFloat, A: CGFloat) -> Color {
        return Color(rgba: (R/255.0, G/255.0, B/255.0, A))
    }
    
    fileprivate class func addDegree(_ addDegree: CGFloat, staticDegree: CGFloat) -> CGFloat {
        let s = staticDegree + addDegree;
        if (s > 360) {
            return s - 360;
        }
        else if (s < 0) {
            return -1 * s;
        }
        else {
            return s;
        }
    }
}
