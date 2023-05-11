# Feather Storage Component

A simple storage component which can store files via [AWS S3](https://aws.amazon.com/s3/) or a local file storage provider.

## Getting started

Adding the dependency

Insert the following entry in your `Package.swift` file to get started:

```swift
.package(url: "https://github.com/feathercms/feather-storage", from: "1.0.0"),
```

Add the `FeatherStorage` libarry as a dependency to your target:

```swift
.product(name: "FeatherStorage", package: "feather-storage"),
```

Add the selected storage provider library to your target:

```swift
// local storage provider
.product(name: "FeatherFileStorage", package: "feather-storage"),

// S3 storage provider
.product(name: "FeatherS3Storage", package: "feather-storage"),
```    
