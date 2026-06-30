import 'package:get/get.dart';

import 'db.dart';
import 'models.dart';

class DirectoryController extends GetxController {
  static DirectoryController get to => Get.find(tag: 'gudesk_directory');

  final directories = <GdDirectory>[].obs;
  final devices = <GdDevice>[].obs;
  final expandedIds = <int>{}.obs;
  final searchQuery = ''.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final dirs = await GdDb.getAllDirectories();
      final devs = await GdDb.getAllDevices();
      directories.assignAll(dirs);
      devices.assignAll(devs);
    } finally {
      isLoading.value = false;
    }
  }

  // ── Tree helpers ──────────────────────────────────────────────────────────

  List<GdDirectory> rootDirectories() =>
      directories.where((d) => d.parentId == null).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<GdDirectory> childDirectories(int parentId) =>
      directories.where((d) => d.parentId == parentId).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<GdDevice> devicesIn(int? directoryId) {
    final q = searchQuery.value.toLowerCase();
    return devices.where((d) {
      if (d.directoryId != directoryId) return false;
      if (q.isEmpty) return true;
      return d.remoteId.toLowerCase().contains(q) ||
          (d.alias?.toLowerCase().contains(q) ?? false) ||
          d.tags.any((t) => t.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });
  }

  List<GdDevice> unassignedDevices() => devicesIn(null);

  bool isExpanded(int id) => expandedIds.contains(id);

  void toggleExpand(int id) {
    if (expandedIds.contains(id)) {
      expandedIds.remove(id);
    } else {
      expandedIds.add(id);
    }
  }

  void expandAll() {
    expandedIds.addAll(directories.map((d) => d.id!));
  }

  void collapseAll() => expandedIds.clear();

  // ── Directory CRUD ────────────────────────────────────────────────────────

  Future<void> createDirectory(String name, {int? parentId}) async {
    final now = DateTime.now();
    final d = GdDirectory(name: name, parentId: parentId, createdAt: now, updatedAt: now);
    final id = await GdDb.insertDirectory(d);
    directories.add(d.copyWith(id: id));
    if (parentId != null) expandedIds.add(parentId);
  }

  Future<void> renameDirectory(GdDirectory d, String newName) async {
    final updated = d.copyWith(name: newName, updatedAt: DateTime.now());
    await GdDb.updateDirectory(updated);
    final idx = directories.indexWhere((e) => e.id == d.id);
    if (idx != -1) directories[idx] = updated;
  }

  Future<void> deleteDirectory(GdDirectory d) async {
    await GdDb.deleteDirectory(d.id!);
    // Remove the directory and all descendants from local list
    final removed = _collectDescendantIds(d.id!);
    removed.add(d.id!);
    directories.removeWhere((e) => removed.contains(e.id));
    expandedIds.removeAll(removed);
    // Devices now have null directory_id — refresh from DB
    await load();
  }

  Set<int> _collectDescendantIds(int parentId) {
    final ids = <int>{};
    for (final child in directories.where((d) => d.parentId == parentId)) {
      ids.add(child.id!);
      ids.addAll(_collectDescendantIds(child.id!));
    }
    return ids;
  }

  // ── Device CRUD ───────────────────────────────────────────────────────────

  Future<void> addDevice(GdDevice d) async {
    final id = await GdDb.insertDevice(d);
    devices.add(d.copyWith(id: id));
  }

  Future<void> updateDevice(GdDevice d) async {
    await GdDb.updateDevice(d);
    final idx = devices.indexWhere((e) => e.id == d.id);
    if (idx != -1) devices[idx] = d;
  }

  Future<void> deleteDevice(GdDevice d) async {
    await GdDb.deleteDevice(d.id!);
    devices.removeWhere((e) => e.id == d.id);
  }

  Future<void> moveDevice(GdDevice d, int? directoryId) async {
    await GdDb.moveDevice(d.id!, directoryId);
    final updated = d.copyWith(directoryId: directoryId);
    final idx = devices.indexWhere((e) => e.id == d.id);
    if (idx != -1) devices[idx] = updated;
  }

  Future<void> toggleFavorite(GdDevice d) async {
    await updateDevice(d.copyWith(isFavorite: !d.isFavorite));
  }

  Future<void> togglePin(GdDevice d) async {
    await updateDevice(d.copyWith(isPinned: !d.isPinned));
  }

  Future<void> setColorLabel(GdDevice d, String? color) async {
    await updateDevice(d.copyWith(colorLabel: color));
  }

  Future<void> setNotes(GdDevice d, String? notes) async {
    await updateDevice(d.copyWith(notes: notes));
  }

  Future<void> setAlias(GdDevice d, String? alias) async {
    await updateDevice(d.copyWith(alias: alias));
  }

  Future<void> updateTags(GdDevice d, List<String> tags) async {
    await updateDevice(d.copyWith(tags: tags));
  }
}
