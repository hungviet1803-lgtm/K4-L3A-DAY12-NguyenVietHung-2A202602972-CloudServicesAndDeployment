# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
#
#   - Multi-stage: stage `builder` cài dependency vào virtualenv /opt/venv,
#     stage runtime chỉ copy virtualenv + source code cần chạy.
#   - Base image slim, cài dependency TRƯỚC khi copy code (tận dụng cache).
#   - Chạy bằng user thường (UID 10001), có HEALTHCHECK gọi /health.
#   - Cổng đọc từ biến PORT (cloud tự gán), mặc định 8000.
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài dependency ───────────────────────────────
FROM python:3.11-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /build
COPY requirements.txt .
RUN pip install -r requirements.txt

# ── Stage 2: runtime — chỉ mang theo thứ cần để chạy ────────────────
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8000

RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home app

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY --chown=app:app app/ ./app/
COPY --chown=app:app utils/ ./utils/

USER 10001

EXPOSE 8000

# Image slim không có curl → dùng Python có sẵn để gọi /health
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request as u; u.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '8000') + '/health', timeout=3)" || exit 1

# Shell form qua `sh -c` để nội suy ${PORT:-8000}; `exec` để uvicorn là PID 1
# và nhận trực tiếp SIGTERM khi container bị dừng.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
