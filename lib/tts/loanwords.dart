/// Common English words in Hinglish replies, spelled the way Hindi text
/// usually writes them. The Hindi voice only knows Hindi phonemes, so a word
/// left in Latin script comes out garbled ("next meeting" -> "next bite").
/// Keys are lowercase.
const loanwords = {
  // Time and planning
  'meeting': 'मीटिंग', 'reminder': 'रिमाइंडर', 'alarm': 'अलार्म',
  'schedule': 'शेड्यूल', 'calendar': 'कैलेंडर', 'appointment': 'अपॉइंटमेंट',
  'deadline': 'डेडलाइन', 'plan': 'प्लान', 'busy': 'बिज़ी', 'free': 'फ़्री',
  'next': 'नेक्स्ट', 'last': 'लास्ट', 'time': 'टाइम', 'minute': 'मिनट',
  'hour': 'आवर', 'second': 'सेकंड', 'week': 'वीक', 'weekend': 'वीकेंड',
  'morning': 'मॉर्निंग', 'evening': 'ईवनिंग', 'night': 'नाइट',
  'late': 'लेट', 'early': 'अर्ली', 'set': 'सेट', 'cancel': 'कैंसिल',
  'confirm': 'कन्फ़र्म', 'update': 'अपडेट', 'check': 'चेक', 'done': 'डन',
  'ready': 'रेडी', 'important': 'इम्पॉर्टेंट', 'urgent': 'अर्जेंट',
  // Work
  'office': 'ऑफ़िस', 'team': 'टीम', 'design': 'डिज़ाइन',
  'project': 'प्रोजेक्ट', 'report': 'रिपोर्ट', 'task': 'टास्क',
  'work': 'वर्क', 'job': 'जॉब', 'interview': 'इंटरव्यू', 'client': 'क्लाइंट',
  'manager': 'मैनेजर', 'boss': 'बॉस', 'call': 'कॉल', 'email': 'ईमेल',
  'mail': 'मेल', 'message': 'मैसेज', 'draft': 'ड्राफ़्ट', 'note': 'नोट',
  'list': 'लिस्ट', 'idea': 'आइडिया', 'problem': 'प्रॉब्लम', 'help': 'हेल्प',
  // Devices
  'phone': 'फ़ोन', 'mobile': 'मोबाइल', 'battery': 'बैटरी',
  'charger': 'चार्जर', 'charge': 'चार्ज', 'percent': 'परसेंट',
  'app': 'ऐप', 'clock': 'क्लॉक', 'timer': 'टाइमर', 'snooze': 'स्नूज़',
  'button': 'बटन',
  'mode': 'मोड',
  'setting': 'सेटिंग',
  'sleep': 'स्लीप',
  'video': 'वीडियो',
  'laptop': 'लैपटॉप',
  'computer': 'कंप्यूटर', 'internet': 'इंटरनेट', 'online': 'ऑनलाइन',
  'wifi': 'वाईफ़ाई', 'password': 'पासवर्ड', 'access': 'एक्सेस', 'account': 'अकाउंट',
  // Weather
  'weather': 'वेदर', 'forecast': 'फ़ोरकास्ट', 'temperature': 'टेम्परेचर',
  'degree': 'डिग्री', 'rain': 'रेन', 'sunny': 'सनी', 'cloudy': 'क्लाउडी',
  // Travel and places
  'traffic': 'ट्रैफ़िक', 'flight': 'फ़्लाइट', 'ticket': 'टिकट',
  'train': 'ट्रेन', 'bus': 'बस', 'cab': 'कैब', 'taxi': 'टैक्सी',
  'booking': 'बुकिंग', 'book': 'बुक', 'trip': 'ट्रिप', 'hotel': 'होटल',
  'restaurant': 'रेस्टोरेंट', 'location': 'लोकेशन', 'address': 'एड्रेस',
  'route': 'रूट', 'map': 'मैप', 'city': 'सिटी', 'airport': 'एयरपोर्ट',
  'station': 'स्टेशन', 'home': 'होम', 'school': 'स्कूल',
  'college': 'कॉलेज', 'class': 'क्लास', 'exam': 'एग्ज़ाम',
  'bangalore': 'बैंगलोर', 'bengaluru': 'बेंगलुरु', 'delhi': 'दिल्ली',
  'mumbai': 'मुंबई',
  // Daily life
  'lunch': 'लंच', 'dinner': 'डिनर', 'breakfast': 'ब्रेकफ़ास्ट',
  'coffee': 'कॉफ़ी', 'tea': 'टी', 'movie': 'मूवी', 'music': 'म्यूज़िक',
  'song': 'सॉन्ग', 'playlist': 'प्लेलिस्ट', 'news': 'न्यूज़',
  'party': 'पार्टी', 'birthday': 'बर्थडे', 'doctor': 'डॉक्टर',
  'gym': 'जिम', 'workout': 'वर्कआउट', 'holiday': 'हॉलिडे', 'leave': 'लीव',
  'bank': 'बैंक', 'payment': 'पेमेंट', 'bill': 'बिल', 'order': 'ऑर्डर',
  'delivery': 'डिलीवरी', 'shopping': 'शॉपिंग', 'friend': 'फ़्रेंड',
  'family': 'फ़ैमिली',
  // Conversation
  'ok': 'ओके', 'okay': 'ओके', 'sorry': 'सॉरी', 'thanks': 'थैंक्स',
  'thank': 'थैंक', 'you': 'यू', 'please': 'प्लीज़', 'sure': 'श्योर',
  'yes': 'यस', 'no': 'नो', 'hello': 'हेलो', 'hi': 'हाय', 'bye': 'बाय',
  'sir': 'सर', 'madam': 'मैडम', 'good': 'गुड', 'great': 'ग्रेट',
  'nice': 'नाइस', 'cool': 'कूल', 'fine': 'फ़ाइन', 'actually': 'एक्चुअली',
  'basically': 'बेसिकली', 'really': 'रियली', 'just': 'जस्ट',
  'maybe': 'मेबी',
};

final _endsInVowel = RegExp('[ा-ौऄ-औ]\$');

/// Devanagari spelling of [word], or null if it isn't in the table.
/// Handles simple plurals: calls -> कॉल्स, movies -> मूवीज़, classes -> क्लासेज़.
String? loanword(String word) {
  final w = word.toLowerCase();
  final direct = loanwords[w];
  if (direct != null) return direct;
  if (w.length > 3 && w.endsWith('es')) {
    final stem = loanwords[w.substring(0, w.length - 2)];
    if (stem != null) return '$stemेज़';
  }
  if (w.length > 2 && w.endsWith('s')) {
    final stem = loanwords[w.substring(0, w.length - 1)];
    if (stem != null) {
      return _endsInVowel.hasMatch(stem) ? '$stemज़' : '$stem्स';
    }
  }
  return null;
}
