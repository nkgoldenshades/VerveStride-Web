// Web-specific download implementation
import 'dart:html' as html;

void triggerDownload(String url, String filename) {
  // For web: Direct download using anchor element
  html.AnchorElement anchorElement = html.AnchorElement(href: url);
  anchorElement.download = filename;
  anchorElement.click();
}
