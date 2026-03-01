-- Drop and Recreate Global Demand Table to include new columns
DROP TABLE IF EXISTS global_demands CASCADE;

CREATE TABLE global_demands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_name TEXT NOT NULL,
  company_name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  country TEXT NOT NULL,
  crop_needed TEXT NOT NULL,
  quantity_required_kg FLOAT8 NOT NULL,
  offered_price_usd TEXT, 
  quality_specs TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE global_demands ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view global demands" ON global_demands FOR SELECT USING (true);

-- Insert Enriched Global Data
INSERT INTO global_demands (buyer_name, company_name, phone, email, country, crop_needed, quantity_required_kg, offered_price_usd, quality_specs)
VALUES 
('Ajith Kumar', 'Al-Bakir Traders LLC', '+971 50 123 4567', 'exports@albakir.ae', 'Dubai, UAE', 'Ginger', 15000, '$1.80/kg', 'Organic, Grade A'),
('Sarah Smith', 'EuroFoods Global', '+44 20 7946 0001', 'sourcing@eurofoods.co.uk', 'London, UK', 'Turmeric', 5000, '$4.20/kg', 'High Curcumin'),
('Tan Wei', 'Singapore Spices Ltd', '+65 6789 1011', 'wei@sgspices.sg', 'Singapore', 'Red Chili', 8000, '$2.10/kg', 'Dried');
