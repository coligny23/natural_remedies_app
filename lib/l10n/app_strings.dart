import 'package:flutter/widgets.dart';

class AppStrings {
  final Locale locale;
  AppStrings(this.locale);

  bool get isSw => locale.languageCode == 'sw';

  static AppStrings of(BuildContext context) {
    return AppStrings(Localizations.localeOf(context));
  }

  String get home => isSw ? 'Nyumbani' : 'Home';
  String get learn => isSw ? 'Jifunze' : 'Learn';
  String get search => isSw ? 'Tafuta' : 'Search';
  String get saved => isSw ? 'Vilivyohifadhiwa' : 'Saved';
  String get settings => isSw ? 'Mipangilio' : 'Settings';

  String get language => isSw ? 'Lugha' : 'Language';
  String get experimental => isSw ? 'Majaribio' : 'Experimental';
  String get personalization => isSw ? 'Ubinafsishaji' : 'Personalization';
  String get privacyTelemetry => isSw ? 'Faragha na Takwimu' : 'Privacy & Telemetry';

  String get english => 'English';
  String get kiswahili => 'Kiswahili';

  String get useExperimentalMl =>
      isSw ? 'Tumia injini ya majaribio ya Akili Mnemba (TFLite)' : 'Use experimental ML engine (TFLite)';

  String get useExperimentalMlSubtitle => isSw
      ? 'Kwa maswali na majibu kwenye kifaa. Kwenye webu, itarudi moja kwa moja kwenye stub.'
      : 'For on-device QA. On web, it automatically falls back to the stub.';

  String get experimentalNote => isSw
      ? 'Kumbuka: Swichi hii huandaa programu kutumia modeli ya Akili Mnemba ya ndani. Kwa sasa bado inatumia stub hadi uongeze modeli halisi.'
      : 'Note: This switch prepares the app to use a local TFLite model. It currently delegates to the stub until you add the real model.';

  String get resetPersonalization =>
      isSw ? 'Weka upya ubinafsishaji' : 'Reset personalization';

  String get resetPersonalizationTitle =>
      isSw ? 'Weka upya ubinafsishaji?' : 'Reset personalization?';

  String get resetPersonalizationMessage => isSw
      ? 'Hii itafuta profile vector ya ndani ya kifaa ili mapendekezo na uboreshaji wa kisemantiki vianze kujifunza upya.'
      : 'This clears your on-device profile vector so recommendations and semantic tailoring relearn from scratch.';

  String get reset => isSw ? 'Weka upya' : 'Reset';
  String get done => isSw ? 'Imekamilika' : 'Done';

  String get personalizationResetDone => isSw
      ? 'Ubinafsishaji umewekwa upya.'
      : 'Personalization has been reset.';

  String get allowAnonymousLogs =>
      isSw ? 'Ruhusu kumbukumbu za matumizi yasiyomtambulisha mtumiaji' : 'Allow anonymous usage logs';

  String get allowAnonymousLogsSubtitle => isSw
      ? 'Matukio huhifadhiwa ndani ya kifaa (bila intaneti). Unaweza kuyahamisha au kuyafuta wakati wowote.'
      : 'Events are stored locally (offline). You can export or clear them anytime.';

  String get exportLogs => isSw ? 'Hamisha kumbukumbu' : 'Export logs';
  String get clearLogs => isSw ? 'Futa kumbukumbu' : 'Clear logs';

  String get nothingToExportTitle =>
      isSw ? 'Hakuna cha kuhamisha' : 'Nothing to export';

  String get nothingToExportMessage =>
      isSw ? 'Bado hakuna kumbukumbu za kuhamisha.' : 'No logs available yet.';

  String get telemetrySubject => 'telemetry.jsonl';

  String get clearLogsTitle => isSw ? 'Futa kumbukumbu?' : 'Clear logs?';

  String get clearLogsMessage => isSw
      ? 'Hii itafuta kumbukumbu zote za matumizi zilizohifadhiwa ndani ya aplikesheni. Huwezi kurejesha kitendo hiki.'
      : 'This will delete all locally stored usage logs. This cannot be undone.';

  String get logsCleared => isSw ? 'Kumbukumbu zimefutwa.' : 'Logs cleared.';

  String get privacyNote => isSw
      ? 'Hakuna taarifa binafsi zinazokusanywa. Kumbukumbu zina matukio ya jumla yasiyotambulisha mtumiaji tu (kwa mfano: “amefungua makala”, “amehifadhi”, “urefu wa alichokitafuta”).'
      : 'No personal data is collected. Logs contain only anonymous events (e.g., “opened article”, “saved”, “search query length”).';

  String get welcome => isSw ? 'Karibu' : 'Welcome';
  String get featuredRemedies => isSw ? 'Tiba Muhimu' : 'Featured Remedies';
  String get categories => isSw ? 'Makundi' : 'Categories';
  String get recent => isSw ? 'Za Hivi Karibuni' : 'Recent';
  String get noItemsFound => isSw ? 'Hakuna vipengele vilivyopatikana' : 'No items found';

  String get searchHint => isSw ? 'Tafuta tiba asili...' : 'Search natural remedies...';
  String get searchResults => isSw ? 'Matokeo ya Utafutaji' : 'Search Results';
  String get noSearchResults => isSw ? 'Hakuna matokeo ya utafutaji' : 'No search results';

  String get savedItems => isSw ? 'Vilivyohifadhiwa' : 'Saved Items';
  String get noSavedItems => isSw ? 'Hakuna vilivyohifadhiwa bado' : 'No saved items yet';

  String get learnRemedies => isSw ? 'Jifunze Tiba' : 'Learn Remedies';
  String get readMore => isSw ? 'Soma zaidi' : 'Read more';
  String get bookmark => isSw ? 'Hifadhi' : 'Bookmark';
  String get removeBookmark => isSw ? 'Ondoa kwenye vilivyohifadhiwa' : 'Remove bookmark';

  String get loading => isSw ? 'Inapakia...' : 'Loading...';
  String get retry => isSw ? 'Jaribu tena' : 'Retry';
  String get errorOccurred => isSw ? 'Hitilafu imetokea' : 'An error occurred';

  String get savedAnswers =>
    isSw ? 'Majibu Yaliyohifadhiwa' : 'Saved Answers';

  String get forYou => isSw ? 'Kwa Ajili Yako' : 'For You';

  String get remedyOfDay =>
      isSw ? 'Dawa ya Mimea ya Leo' : 'Remedy of the Day';

  String get principleOfHealth =>
      isSw ? 'Kanuni ya Afya ya Leo' : 'Principle of Health';

  String get getToKnowRemedy =>
      isSw ? 'Mfahamu mmea' : 'Get to know a remedy';

  String get dailyNaturalHealthCompanion =>
      isSw ? 'Msaidizi wako wa kila siku wa afya asilia'
          : 'Your daily natural health companion';

  String get heroSubtitle =>
      isSw ? 'Tiba • Kanuni • Kujifunza kwa mwongozo'
          : 'Remedies • Principles • Guided learning';

  String get diseases => isSw ? 'Magonjwa' : 'Diseases';
  String get remedies => isSw ? 'Tiba' : 'Remedies';

  String quizQuestion(String herbTitle) => isSw
      ? 'Ni maelezo gani mafupi yanafanana zaidi na "$herbTitle"?'
      : 'Which short description best matches "$herbTitle"?';

  String get correct => isSw ? 'Sahihi!' : 'Correct!';

  String get notQuite => isSw
      ? 'Bado siyo. Jibu sahihi limeonyeshwa hapo juu.'
      : 'Not quite. The correct answer is highlighted above.';

  String get next => isSw ? 'Ifuatayo' : 'Next';

  String get probeAsset => isSw ? 'Kagua faili la asset' : 'Probe asset';

  String loadedSampleJson(int length) => isSw
      ? 'sample.json imepakiwa ($length herufi)'
      : 'Loaded sample.json ($length chars)';

  String failedToLoadAsset(String error) => isSw
      ? 'Imeshindikana kupakia asset: $error'
      : 'Failed to load asset: $error';

  String get searchFieldLabel => isSw
      ? 'Sehemu ya kutafuta tiba asili'
      : 'Search field for natural remedies';

  String get searchFieldHint => isSw
      ? 'Andika kiungo au hali, kwa mfano tangawizi'
      : 'Type an ingredient or condition, for example ginger';

  String get searchExampleHint => isSw
      ? 'Tafuta (mfano, "tangawizi")'
      : 'Search (e.g., "ginger")';

  String loadedCount(int? total) => isSw
      ? 'Vilivyopakiwa: ${total ?? "…"}'
      : 'Loaded: ${total ?? "…"}';

  String resultsCount(int? count) => isSw
      ? 'Matokeo: ${count ?? "…"}'
      : 'Results: ${count ?? "…"}';

  String manifestSample(String value) => isSw
      ? 'Sampuli ya Manifest: $value'
      : 'Manifest sample: $value';

  String get none => isSw ? '(hakuna)' : '(none)';

  String get thinking => isSw ? 'Inafikiri…' : 'Thinking…';

  String couldNotAnswer(String error) => isSw
      ? 'Haikuweza kujibu: $error'
      : 'Could not answer: $error';

  String get answer => isSw ? 'Jibu' : 'Answer';
  String get shareAnswer => isSw ? 'Shiriki jibu' : 'Share answer';
  String get saveAnswer => isSw ? 'Hifadhi jibu' : 'Save answer';
  String get source => isSw ? 'Chanzo' : 'Source';

  String get savedToAnswers => isSw
      ? 'Imehifadhiwa kwenye Majibu'
      : 'Saved to Answers';

  String get typeToSearch => isSw
      ? 'Andika ili kutafuta…'
      : 'Type to search…';

  String get searchError => isSw ? 'Hitilafu ya utafutaji' : 'Search error';

  String get openDetails => isSw ? 'Fungua maelezo' : 'Open details';

  String get doubleTapToOpenDetails => isSw
      ? 'Gusa mara mbili kufungua maelezo'
      : 'Double tap to open details';

  String get noResultsTryAnother => isSw
      ? 'Bado hakuna matokeo. Jaribu neno lingine—kwa mfano, "tangawizi", "pilipili ya cayenne", "udhaifu", "dalili".'
      : 'No results yet. Try another term—e.g., "ginger", "cayenne", "debility", "symptoms".';

  String get savedRemedies =>
    isSw ? 'Tiba Zilizohifadhiwa' : 'Saved Remedies';

  String get filterSavedRemedies =>
      isSw ? 'Chuja tiba zilizohifadhiwa…' : 'Filter saved remedies…';

  String get removeBookmarkTitle =>
      isSw ? 'Ondoa kilichohifadhiwa?' : 'Remove bookmark?';

  String removeFromSavedMessage(String title) => isSw
      ? 'Ondoa “$title” kutoka Vilivyohifadhiwa?'
      : 'Remove “$title” from Saved?';

  String get remove => isSw ? 'Ondoa' : 'Remove';

  String removedItem(String title) => isSw
      ? 'Imeondolewa $title'
      : 'Removed $title';

  String get noSavedRemediesYet => isSw
      ? 'Bado hakuna tiba zilizohifadhiwa.\nFungua makala yoyote kisha gusa alama ya kuhifadhi.'
      : 'No saved remedies yet.\nOpen any article and tap the bookmark icon.';

  String get noSavedRemediesMatchFilter => isSw
      ? 'Hakuna tiba zilizohifadhiwa zinazolingana na kichujio chako.'
      : 'No saved remedies match your filter.';

  String get clear => isSw ? 'Futa' : 'Clear';

  String get basicPrinciples =>
    isSw ? 'Kanuni za Msingi' : 'Basic Principles';

  String get importantHerbs =>
      isSw ? 'Mimea Muhimu' : 'Important Herbs';

  String get diseasesConditions =>
      isSw ? 'Magonjwa na Hali' : 'Diseases & Conditions';

  String basicPrinciplesCount(int count) =>
      isSw ? 'Kanuni za Msingi • $count' : 'Basic Principles • $count';

  String importantHerbsCount(int count) =>
      isSw ? 'Mimea Muhimu • $count' : 'Important Herbs • $count';

  String diseasesConditionsCount(int count) =>
      isSw ? 'Magonjwa na Hali • $count' : 'Diseases & Conditions • $count';

  String get open => isSw ? 'Fungua' : 'Open';

  String get principlesOfHealth =>
      isSw ? 'Kanuni za Afya' : 'Principles of Health';

  String get principlesOfHealthSubtitle => isSw
      ? 'Misingi muhimu, kinga, na maisha yenye afya.'
      : 'Core ideas, prevention, and healthy living.';

  String get importantHerbsSubtitle => isSw
      ? 'Tiba zinazotumika zaidi na jinsi ya kuzitumia.'
      : 'Most-used remedies and how to apply them.';

  String get diseasesConditionsSubtitle => isSw
      ? 'Vinjari kwa mfumo wa mwili—haraka na kwa uwazi.'
      : 'Browse by body system—fast and clear.';

  String get browseEverything =>
      isSw ? 'Vinjari Yote' : 'Browse Everything';

  String get browseEverythingSubtitle => isSw
      ? 'Orodha ya kialfabeti ya maudhui yote'
      : 'Alphabetical list of all content';

  String get notFound => isSw ? 'Haijapatikana' : 'Not found';

  String get addBookmark => isSw ? 'Ongeza kwenye vilivyohifadhiwa' : 'Add bookmark';
  //String get removeBookmark => isSw ? 'Ondoa kwenye vilivyohifadhiwa' : 'Remove bookmark';

  String get removedFromSaved => isSw ? 'Imeondolewa kwenye Vilivyohifadhiwa' : 'Removed from Saved';
  String get savedForLater => isSw ? 'Imehifadhiwa kwa baadaye' : 'Saved for later';

  String get copy => isSw ? 'Nakili' : 'Copy';
  String get copiedToClipboard => isSw ? 'Imenakiliwa' : 'Copied to clipboard';

  String get share => isSw ? 'Shiriki' : 'Share';

  String get overview => isSw ? 'Muhtasari' : 'Overview';
  String get treatment => isSw ? 'Matibabu' : 'Treatment';
  String get causes => isSw ? 'Sababu' : 'Causes';
  String get symptoms => isSw ? 'Dalili' : 'Symptoms';

  String get principlesAZ =>
    isSw ? 'Kanuni (A–Z)' : 'Principles (A–Z)';

  String get digestive => isSw ? 'Mmeng’enyo' : 'Digestive';
  String get respiratory => isSw ? 'Upumuaji' : 'Respiratory';
  String get musculoskeletal => isSw ? 'Mifupa na Misuli' : 'Musculoskeletal';
  String get skin => isSw ? 'Ngozi' : 'Skin';
  String get urinary => isSw ? 'Haja ndogo' : 'Urinary';
  String get reproductive => isSw ? 'Uzazi' : 'Reproductive';
  String get head => isSw ? 'Kichwa' : 'Head';
  String get general => isSw ? 'Jumla' : 'General';

  String get remediesAZ =>
      isSw ? 'Tiba (A–Z)' : 'Remedies (A–Z)';

  String topicsCount(int count) =>
      isSw ? 'mada $count' : '$count topics';  

  String get ok => 'OK';
  String get cancel => isSw ? 'Ghairi' : 'Cancel';

  String onOff(bool value) {
    if (isSw) return value ? 'Imewashwa' : 'Imezimwa';
    return value ? 'On' : 'Off';
  }
}