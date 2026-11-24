#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint foldable_scaffold.podspec` to validate before publishing.
#
# The code reads the iPhone Duo data with APIs of the iOS 27.1 SDK, so building
# this pod needs an Xcode that has it. See the README of the package.
#

Pod::Spec.new do |s|
  s.name             = 'foldable_scaffold'
  s.version          = '0.1.0-dev.9'
  s.summary          = 'Reads the fold and the vertical bars of iPhone Duo for foldable_scaffold.'
  s.description      = <<-DESC
The iOS side of foldable_scaffold: sends the reserved regions of the Flutter view
(the fold, the cameras) and the edge of the system's vertical bars to Dart.
                       DESC
  s.homepage         = 'https://github.com/kunboy1608/foldable_scaffold/tree/main/packages/foldable_scaffold'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'foldable_scaffold' => 'https://github.com/kunboy1608/foldable_scaffold' }
  s.source           = { :path => '.' }
  s.source_files = 'foldable_scaffold/Sources/foldable_scaffold/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version = '5.0'
end
