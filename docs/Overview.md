# Overview

# LedgerTracer

## Giới thiệu

**LedgerTracer** là ứng dụng phân tích và đối soát giao dịch tài chính offline, dành cho các tổ chức/doanh nghiệp sở hữu nhiều tài khoản ngân hàng cần tổng hợp, tìm kiếm, và đối chiếu dữ liệu giao dịch quy mô lớn — mà không cần gửi dữ liệu tài chính nhạy cảm lên bất kỳ dịch vụ đám mây nào.

## Vấn đề thực tế (Pain Point)

Các tổ chức có nhiều tài khoản ngân hàng (tài khoản vận hành, tài khoản lương, ví điện tử nhận thanh toán...) thường xuyên cần:

- **Đối soát cuối kỳ**: tổng hợp thủ công bằng Excel giữa nhiều sao kê ngân hàng — công việc lặp lại, tốn thời gian, dễ sai sót mà kế toán ở các doanh nghiệp nhỏ/vừa vẫn đang làm bằng tay do chưa đủ điều kiện dùng phần mềm kế toán đầy đủ (Misa, QuickBooks, Xero...).
- **Tra cứu nhanh 1 giao dịch cụ thể** trong lịch sử dài hạn (theo tên, nội dung chuyển khoản, khoảng số tiền, khoảng thời gian).
- **Phát hiện giao dịch nội bộ trùng lặp**: khi tiền được chuyển giữa các tài khoản của cùng một tổ chức, giao dịch đó xuất hiện 2 lần trên 2 sao kê khác nhau (một lần "chuyển ra", một lần "chuyển vào") — cần được nhận diện và loại trừ khi tổng hợp dòng tiền thực tế.

Đây là nhu cầu đã được xác nhận bởi cả một ngành phần mềm kế toán, và từng thể hiện rõ ở quy mô rất lớn trong thực tế Việt Nam — ví dụ các đợt vận động quyên góp cộng đồng qua chuyển khoản ngân hàng (điển hình trong các chiến dịch cứu trợ thiên tai), nơi số lượng giao dịch cần tra cứu/đối soát lên đến hàng trăm nghìn, thậm chí hàng triệu giao dịch, đòi hỏi công cụ tìm kiếm và tổng hợp hiệu quả thay vì xử lý thủ công.

## Đối tượng người dùng

Tổ chức/doanh nghiệp nhỏ và vừa, quỹ/đơn vị quản lý dòng tiền qua nhiều tài khoản ngân hàng, cần một công cụ offline-first, riêng tư, và đủ nhanh để làm việc với khối lượng giao dịch lớn tích lũy theo thời gian.

## Chức năng cốt lõi

- **Nhập sao kê giao dịch**: import file sao kê từ một hoặc nhiều tài khoản ngân hàng. Người dùng chỉ cần chọn file mình đang có sẵn — ứng dụng tự nhận diện và xử lý, không yêu cầu người dùng phải biết hay quan tâm đến định dạng kỹ thuật bên dưới. Các định dạng được hỗ trợ:
    - **CSV** — định dạng phổ biến nhất, được hầu hết ngân hàng cung cấp qua Internet Banking (web).
    - **Excel (.xlsx/.xls)** — một số ngân hàng (ví dụ Agribank) cho xuất trực tiếp ngay trong app di động.
    - **MT940** — chuẩn điện SWIFT quốc tế mà nhiều ngân hàng (Vietinbank, Eximbank...) cung cấp riêng cho khách hàng doanh nghiệp để tích hợp phần mềm kế toán và đối soát tự động — phù hợp trực tiếp với nhóm người dùng mục tiêu của LedgerTracer.
    - **JSON** — định dạng chuẩn hóa, dùng cho các nguồn dữ liệu có cấu trúc sẵn hoặc tích hợp hệ thống khác.
    - *(PDF được ghi nhận là giới hạn có chủ đích của dự án — xem mục Nguyên tắc thiết kế.)*
- **Tìm kiếm tức thời (live search)**: tra cứu giao dịch theo tên người chuyển, nội dung chuyển khoản, khoảng số tiền khi người dùng gõ.
- **Đối soát đa tài khoản**: tự động phát hiện và ghép cặp các giao dịch chuyển tiền nội bộ giữa các tài khoản của cùng tổ chức.
- **Thống kê tổng hợp**: xem tổng dòng tiền theo thời gian, theo tài khoản, hỗ trợ ra quyết định nhanh mà không cần tổng hợp thủ công.

## Nguyên tắc thiết kế

- **Offline-first & riêng tư**: toàn bộ dữ liệu được xử lý trên thiết bị, không gửi lên máy chủ bên thứ ba — phù hợp với tính chất nhạy cảm của dữ liệu tài chính.
- **Phạm vi rõ ràng**: LedgerTracer là công cụ đối soát & phân tích giao dịch — **không phải phần mềm kế toán**. Không có hạch toán kép, không hóa đơn, không tính thuế.
- **Tool, không phải Service — không có tài khoản người dùng**: LedgerTracer thuộc nhóm ứng dụng "công cụ xử lý theo phiên" (giống trình đọc PDF, Google Lens, hay các trang tra cứu chỉ số tài khoản game bằng ID) — người dùng đưa dữ liệu sẵn có vào, xem kết quả, rồi thôi, không có khái niệm "trạng thái của tôi" cần được lưu giữ liên tục ở một nơi khác ngoài phiên làm việc hiện tại trên chính thiết bị đó. Điều này khác về bản chất với các app dạng *service* (Google Keep, Gmail...) — nơi tài khoản tồn tại để nối kết trạng thái giữa nhiều phiên/thiết bị (đồng bộ, sao lưu).
- **Giới hạn có chủ đích (trade-off)**: Không hỗ trợ import trực tiếp từ **PDF**, do sao kê PDF là văn bản bán cấu trúc, trình bày khác nhau giữa các ngân hàng, đòi hỏi kỹ thuật trích xuất văn bản (OCR/heuristic) nằm ngoài trọng tâm kỹ thuật của dự án (xử lý dữ liệu lớn/concurrency) và không tự nhiên sinh ra khối lượng giao dịch lớn như các định dạng còn lại. Người dùng có thể dùng tùy chọn xuất CSV/Excel thay thế, vốn đã được hầu hết ngân hàng hỗ trợ.
- **Dữ liệu demo**: toàn bộ dữ liệu sử dụng trong quá trình phát triển và trình diễn là dữ liệu giả lập (synthetic), không sử dụng sao kê thật của bất kỳ cá nhân/tổ chức nào.

## Case Study thực tế

Các tình huống dưới đây cho thấy nhu cầu đối soát giao dịch quy mô lớn không phải là giả định, mà đã và đang xảy ra thật trong nhiều bối cảnh khác nhau tại Việt Nam:

### 1. Quyên góp cộng đồng qua chuyển khoản ngân hàng

Trong các đợt vận động quyên góp cộng đồng quy mô lớn (điển hình là các chiến dịch cứu trợ thiên tai), số lượng giao dịch chuyển khoản đổ về có thể lên đến hàng trăm nghìn, thậm chí hàng triệu giao dịch. Cả người quyên góp (muốn xác minh khoản mình chuyển có được ghi nhận) lẫn ban tổ chức (cần tổng hợp, minh bạch hóa dòng tiền theo thời gian) đều cần tra cứu và thống kê nhanh trên tập dữ liệu giao dịch cực lớn — một công việc gần như bất khả thi nếu làm thủ công.

### 2. Đối soát công nợ và dòng tiền ở doanh nghiệp nhỏ/vừa và hộ kinh doanh

Phần lớn doanh nghiệp nhỏ, hộ kinh doanh tại Việt Nam vẫn quản lý thu chi bằng Excel do chi phí phần mềm kế toán chuyên dụng còn cao. Vấn đề phát sinh rõ rệt khi dữ liệu tăng lên hàng nghìn dòng: khó phát hiện sai sót, dễ trùng lặp hoặc thiếu sót khi nhiều người cùng nhập liệu trên các phiên bản file khác nhau, và việc đối chiếu giữa sổ sách nội bộ với sao kê ngân hàng trở nên tốn thời gian, thiếu tin cậy.

### 3. Đối soát doanh thu sàn thương mại điện tử với sao kê ngân hàng (quy định thuế mới)

Theo Nghị định 117/2025/NĐ-CP về quản lý thuế thương mại điện tử, người bán hàng trên Shopee, TikTok Shop... phải xác định doanh thu chịu thuế dựa trên việc đối chiếu giữa báo cáo doanh thu chi tiết từ sàn (đơn hàng, hoàn trả, phí dịch vụ) với sao kê tài khoản ngân hàng thực nhận, nhằm loại trừ các khoản hoàn trả hoặc phí chưa khấu trừ. Đây là yêu cầu đối soát đa nguồn dữ liệu có tính pháp lý, phát sinh định kỳ hàng tháng/quý, với khối lượng giao dịch tăng theo quy mô bán hàng — một minh chứng rất cụ thể và mang tính thời sự cho nhu cầu mà LedgerTracer hướng tới giải quyết.