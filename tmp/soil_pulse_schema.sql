-- Village Soil Pulse Table
CREATE TABLE IF NOT EXISTS soil_health_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  village TEXT NOT NULL,
  taluk TEXT NOT NULL,
  nitrogen_level TEXT NOT NULL, -- Low, Medium, High
  phosphorus_level TEXT NOT NULL, -- Low, Medium, High
  potassium_level TEXT NOT NULL, -- Low, Medium, High
  ph_level FLOAT8,
  organic_carbon TEXT,
  tested_at DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE soil_health_reports ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Anyone can view soil pulses" 
  ON soil_health_reports FOR SELECT 
  USING (true);

CREATE POLICY "Authenticated users can post soil reports" 
  ON soil_health_reports FOR INSERT 
  WITH CHECK (auth.uid() = profile_id);
