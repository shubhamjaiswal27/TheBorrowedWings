-- Supabase Database Schema for The Borrowed Wings App
-- 
-- Run this SQL in your Supabase SQL Editor to set up the required tables
-- Make sure to enable Row Level Security (RLS) and create appropriate policies

-- Enable Row Level Security
ALTER DATABASE postgres SET "app.jwt_secret" TO 'your-jwt-secret';

-- Create pilots table
CREATE TABLE public.pilots (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  nationality TEXT,
  license_id TEXT,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  
  -- Ensure one pilot per user
  UNIQUE(user_id)
);

-- Create gliders table
CREATE TABLE public.gliders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  manufacturer TEXT,
  model TEXT NOT NULL,
  glider_id TEXT, -- Registration or serial number
  wing_class TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Create flights table
CREATE TABLE public.flights (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  glider_id UUID REFERENCES public.gliders(id) ON DELETE CASCADE NOT NULL,
  started_at TIMESTAMPTZ NOT NULL,
  takeoff_at TIMESTAMPTZ,
  landed_at TIMESTAMPTZ,
  duration_sec INTEGER NOT NULL DEFAULT 0,
  fix_count INTEGER NOT NULL DEFAULT 0,
  igc_path TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Create flight_fixes table (GPS waypoints)
CREATE TABLE public.flight_fixes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  flight_id UUID REFERENCES public.flights(id) ON DELETE CASCADE NOT NULL,
  t TIMESTAMPTZ NOT NULL, -- Timestamp of GPS fix
  lat DOUBLE PRECISION NOT NULL, -- Latitude
  lon DOUBLE PRECISION NOT NULL, -- Longitude
  gps_alt_m INTEGER, -- GPS altitude in meters
  pressure_alt_m INTEGER, -- Pressure altitude in meters
  speed_mps DOUBLE PRECISION, -- Speed in meters per second
  accuracy_m DOUBLE PRECISION, -- GPS accuracy in meters
  seq INTEGER NOT NULL -- Sequence number within flight
);

-- Create indexes for performance
CREATE INDEX idx_pilots_user_id ON public.pilots(user_id);
CREATE INDEX idx_gliders_user_id ON public.gliders(user_id);
CREATE INDEX idx_flights_user_id ON public.flights(user_id);
CREATE INDEX idx_flights_glider_id ON public.flights(glider_id);
CREATE INDEX idx_flights_started_at ON public.flights(started_at DESC);
CREATE INDEX idx_flight_fixes_flight_id_seq ON public.flight_fixes(flight_id, seq);

-- Enable Row Level Security (RLS)
ALTER TABLE public.pilots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gliders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flight_fixes ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies

-- Pilots: Users can only access their own pilot profile
CREATE POLICY "Users can view own pilot profile" ON public.pilots
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own pilot profile" ON public.pilots
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own pilot profile" ON public.pilots
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own pilot profile" ON public.pilots
  FOR DELETE USING (auth.uid() = user_id);

-- Gliders: Users can only access their own gliders
CREATE POLICY "Users can view own gliders" ON public.gliders
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own gliders" ON public.gliders
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own gliders" ON public.gliders
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own gliders" ON public.gliders
  FOR DELETE USING (auth.uid() = user_id);

-- Flights: Users can only access their own flights
CREATE POLICY "Users can view own flights" ON public.flights
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own flights" ON public.flights
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own flights" ON public.flights
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own flights" ON public.flights
  FOR DELETE USING (auth.uid() = user_id);

-- Flight Fixes: Users can only access fixes for their own flights
CREATE POLICY "Users can view own flight fixes" ON public.flight_fixes
  FOR SELECT USING (
    flight_id IN (
      SELECT id FROM public.flights WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own flight fixes" ON public.flight_fixes
  FOR INSERT WITH CHECK (
    flight_id IN (
      SELECT id FROM public.flights WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own flight fixes" ON public.flight_fixes
  FOR UPDATE USING (
    flight_id IN (
      SELECT id FROM public.flights WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own flight fixes" ON public.flight_fixes
  FOR DELETE USING (
    flight_id IN (
      SELECT id FROM public.flights WHERE user_id = auth.uid()
    )
  );

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for pilots table to auto-update updated_at
CREATE TRIGGER update_pilots_updated_at 
  BEFORE UPDATE ON public.pilots 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.pilots TO authenticated;
GRANT ALL ON public.gliders TO authenticated;
GRANT ALL ON public.flights TO authenticated;
GRANT ALL ON public.flight_fixes TO authenticated;