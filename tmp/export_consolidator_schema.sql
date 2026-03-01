-- Border-Breaker (Export Consolidator) Tables
CREATE TABLE IF NOT EXISTS export_lots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  crop_name TEXT NOT NULL,
  target_quantity_kg FLOAT8 NOT NULL,
  quality_grade TEXT NOT NULL, -- Grade A, Organic, etc.
  destination_market TEXT NOT NULL, -- Dubai, London, etc.
  status TEXT DEFAULT 'open', -- open, full, exported
  created_at TIMESTAMPTZ DEFAULT NOW(),
  deadline DATE
);

CREATE TABLE IF NOT EXISTS export_pledges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_id UUID REFERENCES export_lots(id) ON DELETE CASCADE,
  farmer_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  pledged_quantity_kg FLOAT8 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE export_lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE export_pledges ENABLE ROW LEVEL SECURITY;

-- Policies for Lots
CREATE POLICY "Anyone can view export lots" 
  ON export_lots FOR SELECT 
  USING (true);

CREATE POLICY "Authenticated users can create export lots" 
  ON export_lots FOR INSERT 
  WITH CHECK (auth.uid() = creator_id);

-- Policies for Pledges
CREATE POLICY "Anyone can view pledges" 
  ON export_pledges FOR SELECT 
  USING (true);

CREATE POLICY "Users can create their own pledges" 
  ON export_pledges FOR INSERT 
  WITH CHECK (auth.uid() = farmer_id);
