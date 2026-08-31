


String stripGreekAccents(String input) {
  const withAccents = 'άέήίόύώΐΰϊϋΆΈΉΊΌΎΏΪΫ';
  const withoutAccents = 'αεηιουωιυιυΑΕΗΙΟΥΩΙΥ';
  var result = input;
  for (var i = 0; i < withAccents.length; i++) {
    result = result.replaceAll(withAccents[i], withoutAccents[i]);
  }
  return result;
}

String normalizeForSearch(String input) =>
    stripGreekAccents(input.toLowerCase());
