import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eight_express/providers/user_provider.dart';
import 'package:eight_express/models/app_user.dart'; // For UserAddress model

class UserAddressesScreen extends StatelessWidget {
  const UserAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final appUser = userProvider.appUser;

    if (appUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Addresses')),
        body: const Center(child: Text('Please log in to manage addresses.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
      ),
      body: appUser.addresses.isEmpty
          ? const Center(
              child: Text(
                'No addresses added yet.\nTap + to add your first address!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: appUser.addresses.length,
              itemBuilder: (ctx, index) {
                final address = appUser.addresses[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              address.isDefault ? 'Default Address' : 'Address ${index + 1}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: address.isDefault ? Colors.deepOrange : null,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  _showAddEditAddressDialog(context, address: address);
                                } else if (value == 'delete') {
                                  await userProvider.deleteAddress(address.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Address deleted.')),
                                  );
                                } else if (value == 'setDefault' && !address.isDefault) {
                                  UserAddress updated = UserAddress(
                                    id: address.id,
                                    street: address.street,
                                    city: address.city,
                                    state: address.state,
                                    zipCode: address.zipCode,
                                    country: address.country,
                                    isDefault: true,
                                  );
                                  await userProvider.updateAddress(updated);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Default address updated.')),
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                                if (!address.isDefault)
                                  const PopupMenuItem<String>(
                                    value: 'setDefault',
                                    child: Text('Set as Default'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(address.street),
                        Text('${address.city}, ${address.state} ${address.zipCode}'),
                        Text(address.country),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditAddressDialog(context),
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddEditAddressDialog(BuildContext context, {UserAddress? address}) {
    final TextEditingController streetController = TextEditingController(text: address?.street);
    final TextEditingController cityController = TextEditingController(text: address?.city);
    final TextEditingController stateController = TextEditingController(text: address?.state);
    final TextEditingController zipCodeController = TextEditingController(text: address?.zipCode);
    final TextEditingController countryController = TextEditingController(text: address?.country);
    bool isDefault = address?.isDefault ?? false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder( // Use StatefulBuilder to manage checkbox state
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(address == null ? 'Add New Address' : 'Edit Address'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: streetController,
                      decoration: const InputDecoration(labelText: 'Street Address'),
                    ),
                    TextFormField(
                      controller: cityController,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                    TextFormField(
                      controller: stateController,
                      decoration: const InputDecoration(labelText: 'State/Province'),
                    ),
                    TextFormField(
                      controller: zipCodeController,
                      decoration: const InputDecoration(labelText: 'Zip/Postal Code'),
                      keyboardType: TextInputType.number,
                    ),
                    TextFormField(
                      controller: countryController,
                      decoration: const InputDecoration(labelText: 'Country'),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: isDefault,
                          onChanged: (bool? newValue) {
                            setState(() {
                              isDefault = newValue ?? false;
                            });
                          },
                        ),
                        const Text('Set as Default Address'),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (streetController.text.isEmpty ||
                        cityController.text.isEmpty ||
                        stateController.text.isEmpty ||
                        zipCodeController.text.isEmpty ||
                        countryController.text.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields.')),
                      );
                      return;
                    }

                    final newAddress = UserAddress(
                      id: address?.id ?? UniqueKey().toString(), // Use existing ID or generate new
                      street: streetController.text.trim(),
                      city: cityController.text.trim(),
                      state: stateController.text.trim(),
                      zipCode: zipCodeController.text.trim(),
                      country: countryController.text.trim(),
                      isDefault: isDefault,
                    );

                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    if (address == null) {
                      await userProvider.addAddress(newAddress);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address added successfully!')),
                      );
                    } else {
                      await userProvider.updateAddress(newAddress);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address updated successfully!')),
                      );
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: Text(address == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}