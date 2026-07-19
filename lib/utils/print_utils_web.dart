// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void printExpensesHtml(String content) {
  final blob = html.Blob([content], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}
