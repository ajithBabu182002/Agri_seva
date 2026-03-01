-- Global Demand Feed Table
CREATE TABLE IF NOT EXISTS global_demands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_name TEXT NOT NULL,
  country TEXT NOT NULL,
  crop_needed TEXT NOT NULL,
  quantity_required_kg FLOAT8 NOT NULL,
  offered_price_usd TEXT, -- e.g. "$2.5/kg"
  quality_specs TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE global_demands ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Anyone can view global demands" ON global_demands FOR SELECT USING (true);

-- Insert some example data for the demo
INSERT INTO global_demands (buyer_name, country, crop_needed, quantity_required_kg, offered_price_usd, quality_specs)
VALUES 
('Al-Bakir Traders', 'Dubai, UAE', 'Fresh Ginger', 15000, '$1.80/kg', 'Organic, Min 100g/node'),
('EuroFoods Ltd', 'London, UK', 'Turmeric Powder', 5000, '$4.20/kg', 'High Curcumin (>5%), Grade A'),
('Singapore Spices Co', 'Singapore', 'Red Chili', 8000, '$2.10/kg', 'Dried, Stemless');
