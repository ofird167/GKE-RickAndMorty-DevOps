# Stage 1: Build dependencies
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .

# Install dependencies and build wheels
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Final runner image
FROM python:3.12-slim

WORKDIR /app

# Copy installed python dependencies from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# Create a non-root system user
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -m -s /sbin/nologin appuser

# Copy application files
COPY app/ ./app/

# Ensure log and results directory exists and is writable by appuser
RUN mkdir -p logs && \
    chown -R appuser:appgroup /app

# Switch to the non-root user
USER appuser

# Expose port (FastAPI port defaults to 8080 or uses PORT env var)
EXPOSE 8080

# Run FastAPI app
CMD ["python", "-m", "app.main"]
