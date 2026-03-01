-- Updated Export Consolidator Tables with Buyer Details and Full RLS Policies
DROP TABLE IF EXISTS export_pledges CASCADE;
DROP TABLE IF EXISTS export_lots CASCADE;

CREATE TABLE export_lots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  crop_name TEXT NOT NULL,
  target_quantity_kg FLOAT8 NOT NULL,
  quality_grade TEXT NOT NULL,
  destination_market TEXT NOT NULL,
  buyer_name TEXT,
  company_name TEXT,
  buyer_phone TEXT,
  status TEXT DEFAULT 'open',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  deadline TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days')
);

CREATE TABLE export_pledges (
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
CREATE POLICY "Anyone can view export lots" ON export_lots FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create export lots" ON export_lots FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "Owners can update their lots" ON export_lots FOR UPDATE USING (auth.uid() = creator_id);

-- Policies for Pledges (CRITICAL: Added Update and Delete for the user requests)
CREATE POLICY "Anyone can view pledges" ON export_pledges FOR SELECT USING (true);
CREATE POLICY "Users can create their own pledges" ON export_pledges FOR INSERT WITH CHECK (auth.uid() = farmer_id);
CREATE POLICY "Users can update their own pledges" ON export_pledges FOR UPDATE USING (auth.uid() = farmer_id);
CREATE POLICY "Users can delete their own pledges" ON export_pledges FOR DELETE USING (auth.uid() = farmer_id);
