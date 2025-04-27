-- Enable Row Level Security
ALTER TABLE public.membership_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.library_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.digital_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.magazines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.borrowing_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Add basic read policies
CREATE POLICY "Enable read access for authenticated users" ON public.membership_types
    FOR SELECT TO authenticated USING (true);

-- Add table comments
COMMENT ON TABLE public.membership_types IS 'Stores different membership types and their privileges';
COMMENT ON TABLE public.members IS 'Library members and their account information';
COMMENT ON TABLE public.library_items IS 'Contains all library items regardless of type';
COMMENT ON TABLE public.books IS 'Book-specific details extending library_items';
COMMENT ON TABLE public.digital_media IS 'Digital media details extending library_items';
COMMENT ON TABLE public.magazines IS 'Magazine-specific details extending library_items';
COMMENT ON TABLE public.staff IS 'Library staff members and their roles';
COMMENT ON TABLE public.borrowing_transactions IS 'Records of items borrowed by members';
COMMENT ON TABLE public.reservations IS 'Item reservations by members';
COMMENT ON TABLE public.payments IS 'Payment records for fines and fees';
COMMENT ON TABLE public.notifications IS 'Member notifications for various events';