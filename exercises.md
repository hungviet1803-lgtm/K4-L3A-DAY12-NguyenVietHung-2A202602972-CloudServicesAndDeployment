# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên:Nguyễn Việt Hùng  Mã học viên: 2A202602972

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Khi deploy lên Railway, nếu mình quên thêm `AGENT_API_KEY` trong tab Variables
thì với mặc định `"changeme"` app vẫn lên Online, `/health` vẫn 200, nhìn như
mọi thứ ổn. Nhưng URL là public, nên bất kỳ ai đoán thử `X-API-Key: changeme`
đều gọi được `/ask` và tiêu ngân sách LLM của mình, mà mình không hề biết.
Không có mặc định thì `Settings()` ném `ValidationError` ngay khi khởi động
(test `test_thieu_api_key_thi_fail_fast` kiểm tra đúng điều này), deploy báo
lỗi ngay trên dashboard, và mình phải sửa cấu hình trước khi service nhận được
request nào. Lỗi cấu hình lộ ra lúc deploy chứ không lộ ra lúc bị lạm dụng.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log thu được khi gọi `/ask` hai lần với `X-User-Id: sv01`:

```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T10:13:26.880443+00:00", "user_id": "sv01", "tokens_in": 48, "tokens_out": 52, "cost_usd": 3.84e-05}
```

Hai việc làm được mà `print("đã trả lời xong")` không làm được:

1. **Lọc và tổng hợp theo trường.** Vì mỗi dòng là một JSON, công cụ log có
   thể lọc `event = "ask_completed" AND user_id = "sv01"` rồi cộng `cost_usd`
   để biết một user đã tiêu bao nhiêu trong ngày. Với chuỗi tự do thì phải viết
   regex đoán cấu trúc, và chỉ cần ai đó sửa câu chữ là regex hỏng.
2. **Đặt cảnh báo và vẽ biểu đồ.** Ví dụ cảnh báo khi `tokens_in` vượt ngưỡng
   (prompt phình to vì history dài), hoặc vẽ số request theo `timestamp`. Ở log
   trên, `tokens_in` tăng từ 3 lên 48 ở lần gọi thứ hai chính vì history đã được
   ghép vào prompt, điều mà dòng print không cho thấy.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.19 GB (~1190 MB) |
| Multi-stage | 209 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Mình đo trên máy sạch của GitHub Actions: bước
`Image size — single-stage vs multi-stage` trong job `build` của
`.github/workflows/ci.yml` build lại Dockerfile 1 stage ban đầu và bản
multi-stage rồi in `docker images`. Bản multi-stage nhỏ hơn khoảng 5,7 lần,
chênh gần 1 GB.

Phần chênh lệch gồm:

- **Base image:** `python:3.11` bản đầy đủ dựa trên Debian có sẵn gcc, make,
  header file để biên dịch, git, curl và nhiều thư viện hệ thống. `python:3.11-slim`
  bỏ hết những thứ đó. Đây là phần lớn nhất của chênh lệch.
- **Thứ bị copy vào image:** bản 1 stage `COPY . .` kéo theo `tests/`, tài liệu,
  `.venv` nếu có. Bản multi-stage chỉ copy `app/`, `utils/` và virtualenv đã
  cài xong, cộng thêm `.dockerignore` chặn `.git`, `.venv`, `__pycache__`.
- **Cache của pip và file tạm lúc build:** ở bản multi-stage chúng nằm lại ở
  stage `builder`, không đi vào image cuối.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Docker dùng lại cache của một layer khi lệnh và mọi input của nó không đổi;
một layer bị build lại thì mọi layer phía sau trong cùng stage cũng build lại.

Với Dockerfile của mình, khi sửa một ký tự trong `app/main.py`:

- **Dùng lại cache:** cả stage `builder` (`FROM`, tạo venv, `COPY requirements.txt`,
  `RUN pip install`) vì `requirements.txt` không đổi; ở stage runtime thì
  `FROM`, `RUN groupadd/useradd`, `COPY --from=builder /opt/venv`.
- **Chạy lại:** `COPY app/ ./app/` (vì nội dung `app/` đổi) và các layer sau nó:
  `COPY utils/`, `USER`, `HEALTHCHECK`, `CMD`. Các lệnh này chỉ copy file hoặc
  ghi metadata nên mất chưa tới một giây.

Nếu đặt `COPY . .` trước `RUN pip install`, layer COPY chứa cả `app/main.py`,
nên sửa một ký tự là layer đó đổi, kéo theo `pip install` chạy lại toàn bộ:
tải lại và cài lại FastAPI, uvicorn, redis… mất cả phút cho mỗi lần sửa code.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện khi container chạy bằng root:

1. Code Python có lỗ hổng, ví dụ một thư viện bị lỗi deserialize hoặc một chỗ
   gọi shell với input của user, cho phép kẻ tấn công chạy lệnh tùy ý (RCE).
2. Lệnh đó chạy với quyền của process uvicorn. Nếu là root (UID 0) thì kẻ tấn
   công là root trong container: đọc/sửa mọi file, cài công cụ, đọc biến môi
   trường chứa secret.
3. Root trong container có cùng UID 0 với root trên host (khi không dùng user
   namespace). Chỉ cần thêm một lỗ hổng của runtime/kernel, hoặc container được
   mount thư mục host hay `docker.sock`, kẻ tấn công thoát ra ngoài và có quyền
   root trên host.

`USER 10001` cắt chuỗi ở bước 2: RCE vẫn xảy ra nhưng chỉ có quyền của một user
thường, không ghi được vào hệ thống, không cài được gói, và nếu có thoát khỏi
container thì trên host cũng chỉ là UID 10001 không có đặc quyền. Trong CI,
bước `Container smoke test` kiểm tra `docker exec agent id -u` khác 0.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Tối đa **20 request** trong 2 giây. Cách đạt: gửi 10 request lúc 10:00:59
(vẫn trong phút 10:00, bộ đếm lên 10 là đủ hạn mức), sang 10:01:00 bộ đếm reset
về 0, gửi tiếp 10 request lúc 10:01:00–10:01:01. Mỗi phút đồng hồ đều "đúng luật"
10 request, nhưng thực tế là gấp đôi hạn mức trong 2 giây.

Sliding window không bị lỗ hổng này vì nó đếm các request có timestamp trong
60 giây **tính ngược từ thời điểm hiện tại**. Lúc 10:01:00, 10 request lúc
10:00:59 vẫn nằm trong cửa sổ nên request thứ 11 bị 429. Mình đã quan sát trên
bản deploy Railway: 15 request liên tiếp cho `200` × 10 rồi `429` × 5.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Rate limit giới hạn **số request trong 60 giây**, bảo vệ server khỏi bị dội
request (trả 429, thử lại sau). Cost guard giới hạn **tổng tiền trong một tháng**
của mỗi user, bảo vệ ngân sách (trả 402, chờ sang tháng hoặc nâng hạn mức).

- **Rate limit cho qua, cost guard chặn:** user gửi đều đặn 5 request/phút, luôn
  dưới hạn mức 10/phút, nhưng mỗi câu hỏi rất dài và history dài nên tốn nhiều
  token. Sau nhiều ngày tổng chi phí vượt `MONTHLY_BUDGET_USD`, cost guard trả 402
  dù chưa lần nào chạm rate limit. Mình đã thử với ngân sách 0.00005 USD và mỗi
  lượt 0.00003 USD: lần thứ ba bị 402.
- **Cost guard cho qua, rate limit chặn:** user mới trong tháng, gần như chưa
  tiêu gì, nhưng một script lỗi bắn 50 request trong 5 giây với câu hỏi ngắn.
  Tiền vẫn còn nhiều, nhưng request thứ 11 trong cửa sổ 60 giây bị 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

1. Redis mất kết nối. Endpoint gộp trên **cả 3** container cùng lúc trả 503,
   vì cả 3 dùng chung một Redis.
2. Orchestrator thấy liveness probe fail vài lần liên tiếp và coi cả 3 container
   là "chết", nên **restart cả 3**. Các request đang xử lý dở bị cắt ngang.
3. Trong lúc restart, không còn instance nào nhận traffic: load balancer trả
   502/503 cho **mọi** request, kể cả những request không cần Redis.
4. Container khởi động lại xong, nếu Redis vẫn chưa về thì probe lại fail và
   bị restart tiếp, thành vòng lặp restart.
5. Redis về lại sau 30 giây, nhưng service chỉ hồi phục khi container khởi động
   xong: thời gian sập thực tế dài hơn 30 giây.

Tách ra thì: `/health` (liveness) vẫn 200 nên không container nào bị restart;
`/ready` trả 503 nên load balancer chỉ tạm ngừng đẩy request mới. Redis về là
`/ready` 200 trở lại ngay, không có cold start. Mình đã thấy đúng hành vi này
khi chạy app trên máy lúc Redis không chạy: `/health` → 200, `/ready` → 503
`{"status":"not ready","redis":false}`.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Mình quan sát trên bản deploy Railway và khi chạy local: cùng `X-User-Id`, lần gọi
đầu `history_length: 0`, lần sau `history_length: 2`, và cứ mỗi lượt tăng thêm 2
(một câu hỏi và một câu trả lời), tối đa 20 do `LTRIM`.

Với Redis, 3 instance đọc/ghi cùng một key `history:<user_id>` nên dù load
balancer đẩy request vào instance nào, `history_length` vẫn tăng đều 0 → 2 → 4 → 6.

Nếu lưu trong dict Python, mỗi instance có dict riêng trong RAM của nó. Request
được chia vòng quanh 3 instance, nên con số **nhảy lung tung và tăng chậm**: ví
dụ 0 (vào A) - 0 (vào B) - 0 (vào C) - 2 (lại vào A) -2 - 2 - 4… Agent "quên"
những gì user vừa nói ở instance khác. Thêm nữa, instance nào bị restart hay
redeploy thì history của nó mất sạch, về lại 0.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

**Lỗi:** sau khi deploy lên Railway, `/health` 200 và `/ready` 200
(`redis: true`), gọi `/ask` không có key trả 401 đúng như mong đợi, nhưng gọi
`/ask` **có** key (key mới lưu ở `DEPLOY_API_KEY` trong `.env`) vẫn trả
`401 {"detail":"invalid or missing API key"}`.

**Tìm nguyên nhân:** 401 (không phải 500) nghĩa là app đã đọc được
`AGENT_API_KEY` (nếu thiếu thì `Settings()` lỗi thành 500), chỉ là giá trị
khác key mình gửi. Mình thử gọi lại bằng key `AGENT_API_KEY` dùng ở máy local
thì được 200, vậy là lúc thêm biến trên Railway mình đã dán nhầm key local thay
vì key mới.

**Sửa:** vào tab Variables của service, sửa `AGENT_API_KEY` thành key mới rồi
redeploy. Kiểm tra lại: key mới → 200, key local cũ → 401. Như vậy key trên
cloud và key ở máy tách riêng: lộ một key không ảnh hưởng môi trường kia.
