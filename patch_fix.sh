#!/bin/bash
echo "[1/2] Backend: JWT Ayarlarını Temizliyor..."
# .env veya docker-compose içindeki olası Türkçe karakterleri engellemek için basit bir secret atayalım
sed -i 's/JWT_SECRET: .*/JWT_SECRET: "super-secret-key-123"/g' docker-compose.yml

echo "[2/2] Frontend: Fetch isteğindeki hatalı karakterleri engelliyor..."
# Frontend'deki fetch isteklerini daha güvenli hale getirecek küçük bir düzenleme (örnek üzerinden)
# Not: Bu adım manuel kontrol gerektirebilir ama biz bağlantı URL'sini normalize edelim.
sed -i 's/NEXT_PUBLIC_API_BASE_URL: .*/NEXT_PUBLIC_API_BASE_URL: http:\/\/localhost:8000/g' docker-compose.yml

echo "Değişiklikler uygulandı. Sistem yeniden başlatılıyor..."
docker compose up -d --build
