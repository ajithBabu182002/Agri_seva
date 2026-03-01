-- 1. Create the bookings table to track who booked which trip
CREATE TABLE IF NOT EXISTS transport_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES transport_relay(id) ON DELETE CASCADE,
  booker_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  sacks_booked INT NOT NULL,
  total_price FLOAT8 NOT NULL,
  booked_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE transport_bookings ENABLE ROW LEVEL SECURITY;

-- 3. Policies
CREATE POLICY "Users can view their own bookings" 
  ON transport_bookings FOR SELECT 
  USING (auth.uid() = booker_id);

CREATE POLICY "Trip owners can view bookings for their trips" 
  ON transport_bookings FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM transport_relay 
      WHERE transport_relay.id = transport_bookings.trip_id 
      AND transport_relay.profile_id = auth.uid()
    )
  );

CREATE POLICY "Users can create bookings" 
  ON transport_bookings FOR INSERT 
  WITH CHECK (auth.uid() = booker_id);
