Background
----------
These are some notes for functional testing to make sure the Munki Enrollment Client operates as a technician would expect.  Some givens here include:
   * You have access to and can locate and modify a test computer's manifest in your munki repository.
   * You know how to delete the client's PKI enrollment materials (_/private/var/root/client-identity.pem_); e.g.:<pre>
sudo rm /private/var/root/client-identity.pem
</pre>

Simple Tests
----------
### Missing Manifest Case ###
   * Remove the manifest for the test computer from the munki repository.
   * Remove the PKI materials from the test client.  Run the Munki Enrollment Client for testing.  Choose a group and supply a computer name during enrollment.
   * Verify that:
      * The MEC prompts for group and computer name.
      * A new manifest file with the client's serial is created.
      * The name for the computer chosen is recorded in the __metadata_ dictionary of the computer's manifest.
      * The _included_manifests_ key in the computer's manifest is set to the chosen group.
      * The PKI materials are created on the client.  
   * Once again, remove the manifest for the test computer from the munki repository.
   * Leave the PKI materials on the test client.  Run the Munki Enrollment Client for testing.  Choose a group and supply a computer name during enrollment.
   * Verify that:
      * The MEC prompts for group and computer name.
      * A new manifest file with the client's serial is created.
      * The name for the computer chosen is recorded in the __metadata_ dictionary of the computer's manifest.
      * The _included_manifests_ key in the computer's manifest is set to the chosen group.
      * The PKI materials remain on the client.

### Manifest Present, No Name in Manifest Case ###
   * Edit the manifest for the test computer from the munki repository, removing the _computer_name_ key from its __metadata_ dict.
   * Remove the PKI materials from the test client.  Run the Munki Enrollment Client for testing.  Choose a group and supply a computer name during enrollment.
   * Verify that:
      * The MEC prompts for group and computer name.
      * The name for the computer chosen is recorded in the __metadata_ dictionary of the computer's manifest.
      * The _included_manifests_ key in the computer's manifest is set to the chosen group.
      * The PKI materials are created on the client.  
      * _scutil_ indicates the name is set.
   * Once again, edit the manifest for the test computer from the munki repository, removing the _computer_name_ key from its __metadata_ dict.
   * Leave the PKI materials on the test client.  Run the Munki Enrollment Client for testing.  Choose a group and supply a computer name during enrollment.
   * Verify that:
      * The MEC prompts for group and computer name.
      * The name for the computer chosen is recorded in the __metadata_ dictionary of the computer's manifest.
      * The _included_manifests_ key in the computer's manifest is set to the chosen group.
      * The PKI materials remain on the client.
      * _scutil_ indicates the name is set.

### Manifest Present, Name in Manifest Case ###
   * Verify that the manifest for the test computer has a _name_ key from the __metadata_ dict and an _included_manifests_ entry representing the selected group.
      * Note the computer name and group.
   * Remove the PKI materials from the test client.  Run the Munki Enrollment Client for testing.
   * Verify that the MEC offers the choice for keeping the existing name and group or choosing another one.
   * Choose to keep the existing name and group.
   * Verify that:
      * The name for the computer chosen remains the same in the __metadata_ dictionary of the computer's manifest.
      * The _included_manifests_ key in the computer's manifest remains set to the same group.
      * The PKI materials are created on the client.  
      * _scutil_ indicates the name is set.
   * Once again, remove the client PKI materials.  Run the Munki Enrollment Client for testing.
   * Verify that the MEC offers the choice for keeping the existing name and group or choosing another one.
   * Choose to change the name or group, picking a different group and a different name.
      * Note the new computer name and group.
   * Verify that:
      * The name for the computer chosen is updated in the __metadata_ dictionary of the computer's manifest.
      * The _included_manifests_ key in the computer's manifest reflects the newly chosen group.
      * The PKI materials are created on the client.  
      * _scutil_ indicates the name is set.
      
   * Verify that the manifest for the test computer has a _name_ key from the __metadata_ dict and an _included_manifests_ entry representing the selected group.
      * Note the computer name and group.
   * Verify the existence of the client PKI materials.  Run the Munki Enrollment Client for testing.
   * Verify that the MEC offers the choice for keeping the existing name and group or choosing another one.
   * Choose to keep the existing name and group.
   * Verify that:
      * The name for the computer chosen remains the same in the __metadata_ dictionary of the computer's manifest.
      * The _included_manifests_ key in the computer's manifest remains set to the same group.
      * _scutil_ indicates the name is set.
   * Again, verify the existence of the client PKI materials.  Run the Munki Enrollment Client for testing.
   * Verify that the MEC offers the choice for keeping the existing name and group or choosing another one.
   * Choose to change the name or group, picking a different group and a different name.
      * Note the new computer name and group.
   * Verify that:
      * The name for the computer chosen is updated in the __metadata_ dictionary of the computer's manifest.
      * The _included_manifests_ key in the computer's manifest reflects the newly chosen group.
      * _scutil_ indicates the name is set.