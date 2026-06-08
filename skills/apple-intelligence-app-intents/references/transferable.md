# Transferable representations for AppEntity (WWDC 2026)

`Transferable` is how Apple Intelligence moves your entity between apps. Always provide several representations — Siri picks the richest one the receiver understands.

## Full recipe

```swift
extension LandmarkEntity: Transferable {
    public static var transferRepresentation: some TransferRepresentation {

        // 1. Rich, file-backed format.
        FileRepresentation(exportedContentType: .pdf) { @MainActor landmark in
            let url = URL.documentsDirectory.appending(path: "\(landmark.name).pdf")
            let renderer = ImageRenderer(content: VStack {
                Image(landmark.landmark.backgroundImageName)
                    .resizable().aspectRatio(contentMode: .fit)
                Text(landmark.name)
                Text("Continent: \(landmark.continent)")
                Text(landmark.description)
            }.frame(width: 600))
            renderer.render { size, render in
                var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
                pdf.beginPDFPage(nil); render(pdf); pdf.endPDFPage(); pdf.closePDF()
            }
            return .init(url)
        }

        // 2. Raw binary image.
        DataRepresentation(exportedContentType: .image) { try $0.imageRepresentationData }

        // 3. Plain text fallback (always include this).
        DataRepresentation(exportedContentType: .plainText) {
            Data("""
            Landmark: \($0.name)
            Description: \($0.description)
            """.utf8)
        }

        // 4. Structured value for apps that understand the type (e.g. Maps).
        ValueRepresentation(exporting: \.placeDescriptor)
    }
}

public var placeDescriptor: PlaceDescriptor {
    PlaceDescriptor(
        representations: [.coordinate(landmark.locationCoordinate)],
        commonName: landmark.name
    )
}
```

## Rules

- **Always include `.plainText`.** It is the universal fallback.
- **Prefer `ValueRepresentation` over `DataRepresentation`** for structured types (`PlaceDescriptor`, `Contact`, etc.). When a shortcut hands the entity to Maps, Maps receives a navigable place, not just bytes.
- The `IntentValueRepresentation` type (new in WWDC26) lets you bridge to system intent values without leaving the App Intents type system.
- Heavy formats (PDF/image) should be lazily rendered inside the closure — never pre-rendered at app launch.
