//
//  SportsGroupSlider.swift
//  Nutriflow
//
//  Created by Artem on 8.08.26.
//

import SwiftUI

protocol GroupTabItem: CaseIterable, Hashable {
    var symbolImage: String { get }
}

struct SportsGroupSlider<Item: GroupTabItem>: View {
    @Binding var selection: [Item]
    
    ///View Properties
    @State private var containerSize: CGSize = .zero
    @State private var itemRects: [Item: CGRect] = [:]
    ///Gesture properties
    @GestureState private var isActive: Bool = false
    @State private var startOffset: CGFloat = 0
    @State private var endOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
   
    
    var body: some View {
        HStack(spacing: 0){
            ForEach(tabs, id: \.symbolImage){tab in
                TabItemView(for: tab, tint: .gray)
                    .onGeometryChange(for: CGRect.self){
                        $0.frame(in: .named("container"))
                    }action: {
                        newValue in itemRects[tab] = newValue
                    }
            }
            
        }
            .frame(height: 55)
            .frame(maxWidth: .infinity)
            .contentShape(.rect(cornerRadius: 15))
            .overlay(alignment: .leading){
                ///Draggable left right and movemend indicators
                if let firstSelected = selection.first , let lastSelected = selection.last{
                ///identifiying its posions
                    let firstRect = itemRects[firstSelected] ?? .zero
                    let lastRect = itemRects[lastSelected] ?? .zero
                    
                    let sw = min(max(firstRect.minX+startOffset, 0), containerSize.width-tabWidth)
                    let ew = max(min(lastRect.maxX+endOffset, containerSize.width), tabWidth)
                    let blockWidth = max(ew-sw, tabWidth)
                    
                    let clampedDragOffset = min(max(dragOffset, -sw), containerSize.width - blockWidth-sw)
                    
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.primary.opacity(0.12))
                        .strokeBorder(Color.primary, lineWidth: 1)
                        .frame(width: blockWidth)
                        .offset(x: clampedDragOffset)
                        .overlay{
                            Rectangle()
                                .foregroundStyle(.clear)
                                .contentShape(.rect)
                                .gesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .named("container")
                                    )
                                    .onChanged { value in
                                        dragOffset = value.translation.width
                                    }.onEnded{ value in
                                        withAnimation(animation){
                                            endResizeDragging(firstRect)
                                            dragOffset = 0
                                        }
                                        
                                    }
                                
                                )
                            /// Two Resible blocks on both ends
                                .padding(.horizontal,10)
                            
                        }
                        .overlay(alignment: .leading){
                            UnevenRoundedRectangle(topLeadingRadius: 15, bottomLeadingRadius: 15)
                                .frame(width: 10)
                                .overlay{
                                    Capsule()
                                        .fill(.windowBackground)
                                        .frame(width: 2, height: 30)
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .named("container")
                                    )
                                    .onChanged { value in
                                        startOffset = value.translation.width
                                    }.onEnded{ value in
                                        withAnimation(animation){
                                            endResizeTranslation(isLeading: true)
                                            startOffset = 0
                                        }
                                        
                                    }
                                
                                )
                                .offset(x: clampedDragOffset)
                        }
                        .overlay(alignment: .trailing){
                            UnevenRoundedRectangle(bottomTrailingRadius: 15, topTrailingRadius: 15)
                                .frame(width: 10)
                                .overlay{
                                    Capsule()
                                        .fill(.windowBackground)
                                        .frame(width: 2, height: 30)
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .named("container")
                                    )
                                    .onChanged { value in
                                        endOffset = value.translation.width
                                    }.onEnded{ value in
                                        withAnimation(animation){
                                            endResizeTranslation(isLeading: false)
                                            endOffset = 0
                                        }
                                        
                                    }
                                
                                )
                                .offset(x: clampedDragOffset)
                        }
                        .offset(x: max(min(firstRect.minX+startOffset, lastRect.minX), 0))
                        ///Active Block Masking
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .leading){
                            MaskContent()
                                .mask(alignment: .leading){
                                    Rectangle()
                                        .padding(.horizontal, 10)
                                        .frame(width: blockWidth)
                                        .offset(x: clampedDragOffset)
                                        .offset(x: max(min(firstRect.minX+startOffset, lastRect.minX), 0))
                                }
                                .allowsHitTesting(false)
                        }
                }
                
            }
            .background{RoundedRectangle(cornerRadius: 15)
                    .fill(.bar)
                    .strokeBorder(Color.gray.tertiary, lineWidth: 1)
            }
        
            .onGeometryChange(for: CGSize.self){
                $0.size
            }
            action: { newValue in
                containerSize = newValue
            }
            .coordinateSpace(.named("container"))
        ///Double checking selection update from outside
            .onChange(of: selection){
                oldValue, newValue in
                verifySelection(newValue)
            }
            .onAppear{
                verifySelection(selection)
            }
    }
    
    ///Tab Item View
    @ViewBuilder
    private func TabItemView(for item: Item, tint: Color)-> some View{
        Image(systemName: item.symbolImage)
            .font(.body)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 55)
    }
    
    @ViewBuilder
    private func MaskContent()-> some View{
        HStack(spacing: 0){
            ForEach(tabs, id: \.symbolImage){tab in
                TabItemView(for: tab, tint: .primary)
            }
            
        }
    }
    
    private func endResizeTranslation(isLeading: Bool){
        if let firstSelection = selection.first,
           let lastSelection = selection.last,
           let firstIndex = tabs.firstIndex(of: firstSelection),
           let lastIndex = tabs.firstIndex(of: lastSelection),
           let firstRect = itemRects[firstSelection],
           let lastRect = itemRects[lastSelection]{
            if isLeading{
                let endResult = (firstRect.minX) + startOffset
                let fallingIndex = Int((endResult / tabWidth).rounded())
                let index = min(max(fallingIndex, 0), lastIndex)
                
                let newSelection = Array(tabs[index...lastIndex])
                selection = newSelection
            }else{
                let endResult = lastRect.minX + endOffset
                let fallingIndex = Int((endResult / tabWidth).rounded())
                let index = min(max(fallingIndex, firstIndex), tabs.count - 1)
                
                let newSelection = Array(tabs[firstIndex...index])
                selection = newSelection
                
            }
        }
            
    }
    
    private func endResizeDragging(_ firstRect: CGRect){
        if let lastIndex = selection.indices.last{
            let endResult = firstRect.minX + dragOffset
            let rawFallingIndex = Int((endResult / tabWidth).rounded())
            
            let maxStartIndex = tabs.count - 1 - lastIndex
            let fallingIndex = min(max(rawFallingIndex, 0), maxStartIndex)
            
            let newStartIndex = fallingIndex
            let newEndIndex = lastIndex + fallingIndex
            selection = Array(tabs[newStartIndex...newEndIndex])
            
            
        }
    }
    
    private func verifySelection(_ newValue: [Item]){
        if let first = newValue.first , let last = newValue.last,
           let firstIndex = tabs.firstIndex(of: first),
           let lastIndex = tabs.firstIndex(of: last){
            if lastIndex >= firstIndex {
                let newSelection = Array(tabs[firstIndex...lastIndex])
                if newSelection != newValue{
                    selection = newSelection
                }
            }else {
                print("Invaid selection")
                selection = [tabs[firstIndex]]
            }
        }
    }
    
    private var tabs: [Item]{
        Array(Item.allCases)
    }
    
    private var tabWidth: CGFloat{
        containerSize.width/CGFloat(tabs.count)
        
    }
    
    private var animation: Animation {
        .interactiveSpring(duration: 0.15, extraBounce: 0, blendDuration: 0)
    }
}




enum Sport: String, GroupTabItem {
    case soccer = "soccerball"
    case tennis = "tennis.racket"
    case basketball = "basketball.fill"
    case cricket = "cricket.ball.fill"
    case skiing = "skis"
    case golf = "figure.golf"
    
    var symbolImage: String {
        self.rawValue
    }
    
}

struct SportView: View {
    @State private var selection: [Sport] = [.basketball]
    var body: some View {
        NavigationStack{
            VStack{
               SportsGroupSlider(selection: $selection)
            }.padding()
        }
    }
}

#Preview {
    SportView()
}
