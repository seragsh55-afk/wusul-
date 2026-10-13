CREATE TABLE families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  head_name TEXT NOT NULL,
  phone TEXT,
  members_count INT NOT NULL,
  national_id_hash TEXT UNIQUE,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  qr_code TEXT UNIQUE DEFAULT 'WUS-' || substr(md5(random()::text),1,5),
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE TABLE distributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID REFERENCES families(id),
  basket_type TEXT,
  delivered_at TIMESTAMP DEFAULT NOW(),
  status TEXT DEFAULT 'delivered'
);
INSERT INTO families (head_name, phone, members_count, lat, lng, national_id_hash) VALUES
('عائلة الثورة - ام درمان', '0911234567', 6, 15.6445, 32.4771, 'sd001'),
('عائلة كرري', '0911234568', 4, 15.65, 32.48, 'sd002');
