/// Which screen search was opened from.
///
/// Results of the matching kind get a bonus, so opening search from History and
/// typing a topic name puts that topic's past alarms above the topic itself.
enum SearchScope { topics, history, settings }
