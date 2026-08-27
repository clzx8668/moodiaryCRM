/// 首页记录排序方式
enum DiarySort {
  createdDesc(0, '创建时间 ↓'),
  createdAsc(1, '创建时间 ↑'),
  modifiedDesc(2, '修改时间 ↓'),
  modifiedAsc(3, '修改时间 ↑'),
  name(4, '名称');

  const DiarySort(this.value, this.label);

  final int value;
  final String label;

  static DiarySort fromIndex(int index) {
    return DiarySort.values.firstWhere(
      (e) => e.value == index,
      orElse: () => DiarySort.createdDesc,
    );
  }
}
