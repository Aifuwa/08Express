import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/models/app_user.dart';

class UserAddressesScreen extends StatelessWidget {
  const UserAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final appUser = userProvider.appUser;
    const Color primaryColor = Color(0xFFFE7F2D); // Brand Orange

    if (appUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return Scaffold(
      // Soft background gradient
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withOpacity(0.1), // Very soft orange tint
              const Color(0xFFF4F7FA),       // Soft light grey
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // Beautiful Custom Header
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: const Text(
                  "My Delivery Addresses",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                background: Container(color: Colors.transparent),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Address List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: appUser.addresses.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState(primaryColor))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final address = appUser.addresses[index];
                          return _AddressTile(
                            address: address,
                            primaryColor: primaryColor,
                            onEdit: () => _showFormSheet(context, address: address),
                            onDelete: () => userProvider.deleteAddress(address.id),
                            onSetDefault: () {
                              UserAddress updated = UserAddress(
                                id: address.id,
                                street: address.street,
                                city: address.city,
                                state: address.state,
                                zipCode: address.zipCode,
                                country: address.country,
                                isDefault: true,
                              );
                              userProvider.updateAddress(updated);
                            },
                          );
                        },
                        childCount: appUser.addresses.length,
                      ),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSheet(context),
        backgroundColor: primaryColor,
        elevation: 4,
        icon: const Icon(Icons.add_location_rounded, color: Colors.white),
        label: const Text(
          "Add New Address",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.network(
          'https://cdn-icons-png.flaticon.com/512/1321/1321722.png', // Location illustration
          height: 150,
          color: color.withOpacity(0.5),
        ),
        const SizedBox(height: 20),
        const Text("Where should we deliver?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
      ],
    );
  }

  void _showFormSheet(BuildContext context, {UserAddress? address}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddressFormSheet(address: address),
    );
  }
}

// --- BEAUTIFUL ADDRESS TILE ---
class _AddressTile extends StatelessWidget {
  final UserAddress address;
  final Color primaryColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AddressTile({
    required this.address,
    required this.primaryColor,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Icon Badge
            Container(
              height: 55,
              width: 55,
              decoration: BoxDecoration(
                color: address.isDefault ? primaryColor.withOpacity(0.1) : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                address.isDefault ? Icons.stars_rounded : Icons.location_on_rounded,
                color: address.isDefault ? primaryColor : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Address Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.isDefault)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text("DEFAULT", style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  Text(address.street, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text("${address.city}, ${address.state}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            // Menu
            PopupMenuButton<int>(
              icon: const Icon(Icons.more_horiz, color: Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              onSelected: (val) {
                if (val == 1) onEdit();
                if (val == 2) onSetDefault();
                if (val == 3) onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 1, child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text("Edit")])),
                if (!address.isDefault)
                  const PopupMenuItem(value: 2, child: Row(children: [Icon(Icons.check_circle_outline, size: 20), SizedBox(width: 8), Text("Set Default")])),
                const PopupMenuItem(value: 3, child: Row(children: [Icon(Icons.delete_outline, size: 20, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- CLEAN FORM SHEET ---
class _AddressFormSheet extends StatefulWidget {
  final UserAddress? address;
  const _AddressFormSheet({this.address});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  late TextEditingController street;
  late TextEditingController city;
  late TextEditingController state;
  late TextEditingController zip;
  late bool isDefault;

  @override
  void initState() {
    super.initState();
    street = TextEditingController(text: widget.address?.street);
    city = TextEditingController(text: widget.address?.city);
    state = TextEditingController(text: widget.address?.state);
    zip = TextEditingController(text: widget.address?.zipCode);
    isDefault = widget.address?.isDefault ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 25, top: 12, left: 25, right: 25),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 25),
            Text(widget.address == null ? "Add Delivery Address" : "Update Address", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            _buildField(street, "Street Address", Icons.map_outlined),
            const SizedBox(height: 15),
            Row(children: [
              Expanded(child: _buildField(city, "City", Icons.location_city_outlined)),
              const SizedBox(width: 15),
              Expanded(child: _buildField(state, "State", Icons.explore_outlined)),
            ]),
            const SizedBox(height: 15),
            _buildField(zip, "Zip Code", Icons.pin_drop_outlined, TextInputType.number),
            const SizedBox(height: 15),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Make this my default address", style: TextStyle(fontWeight: FontWeight.w500)),
              value: isDefault,
              activeColor: const Color(0xFFFE7F2D),
              onChanged: (v) => setState(() => isDefault = v),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                final up = Provider.of<UserProvider>(context, listen: false);
                final newAddr = UserAddress(
                  id: widget.address?.id ?? UniqueKey().toString(),
                  street: street.text,
                  city: city.text,
                  state: state.text,
                  zipCode: zip.text,
                  country: "Nigeria",
                  isDefault: isDefault,
                );
                if (widget.address == null) up.addAddress(newAddr); else up.updateAddress(newAddr);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE7F2D),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: const Text("Save Address", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String l, IconData i, [TextInputType? t]) {
    return TextField(
      controller: c,
      keyboardType: t,
      decoration: InputDecoration(
        labelText: l,
        prefixIcon: Icon(i, color: Colors.grey, size: 22),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey.shade100)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFFE7F2D))),
      ),
    );
  }
}