import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Căn giữa nội dung trong khoảng trống mà cha cấp cho, **và** vẫn cuộn được khi
/// nội dung cao hơn khoảng đó.
///
/// ## Vì sao không phải là [Center]
///
/// Một [Center] trong khung có chiều cao xác định thì căn giữa đúng, nhưng nội
/// dung cao hơn màn hình sẽ tràn. Một [ListView] thì ngược lại: cuộn được, song
/// mọi thứ dán lên mép trên, nên một panel cao 200px giữa màn hình rộng 1000px
/// nằm lọt thỏm ở góc với 800px trống bên dưới.
///
/// Widget này ghép hai nửa: ép chiều cao tối thiểu bằng đúng chiều cao khung
/// nhìn rồi căn giữa bên trong. Nội dung thấp thì nằm giữa, nội dung cao thì đẩy
/// khối lớn hơn khung nhìn và cuộn bình thường từ trên xuống. Không có nhánh nào
/// phải chọn trước theo kích thước nội dung.
///
/// Khi cha **không** giới hạn chiều cao (đặt trong một `ListView` khác chẳng
/// hạn) thì không có "giữa" nào để căn, và widget lùi về đúng nội dung của nó.
class ViewportCenter extends StatelessWidget {
  const ViewportCenter({
    required this.child,
    this.padding = const EdgeInsets.all(Gap.screen),
    super.key,
  });

  final Widget child;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedHeight) {
        return Padding(padding: padding, child: Center(child: child));
      }
      // Trừ đi phần đệm: `minHeight` đo khối **bên trong** vùng đệm, nên lấy
      // nguyên chiều cao khung nhìn sẽ làm trang cuộn được đúng bằng chỗ đệm
      // dù nội dung thừa chỗ.
      final minHeight = (constraints.maxHeight - padding.vertical).clamp(
        0.0,
        double.infinity,
      );
      return SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Center(child: child),
        ),
      );
    },
  );
}
