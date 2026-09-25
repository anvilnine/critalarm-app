import AppIntents
import WidgetKit

/// A topic, as the per-topic widget's picker lists it. The id is the topic
/// name, which is also how the snapshot keys topics.
struct TopicEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Topic"
    static var defaultQuery = TopicQuery()

    let id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

/// The picker's list: the topics in the widget snapshot, nothing fetched.
/// Signed out, or before the app has run, the list is empty.
struct TopicQuery: EntityQuery {
    /// A topic picked earlier stays picked even after it leaves the snapshot,
    /// so the widget can say "Topic not found" instead of losing its setting.
    func entities(for identifiers: [String]) async throws -> [TopicEntity] {
        identifiers.map(TopicEntity.init(id:))
    }

    func suggestedEntities() async throws -> [TopicEntity] {
        let snapshot = WidgetSnapshotStore.read()
        guard let snapshot, snapshot.connected else { return [] }
        return snapshot.topics.map { TopicEntity(id: $0.name) }
    }

    /// A freshly placed widget shows the first topic in the list.
    func defaultResult() async -> TopicEntity? {
        try? await suggestedEntities().first
    }
}

struct SelectTopicIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Topic"
    static var description = IntentDescription("Pick the topic this widget shows.")

    @Parameter(title: "Topic")
    var topic: TopicEntity?

    init() {}

    init(topic: TopicEntity?) {
        self.topic = topic
    }
}
