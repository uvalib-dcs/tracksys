$(function() {

   $(".sel-cb").on("click", function() {
      var checked = $(this).is(":checked");
      var cn = "."+$(this).attr('class').replace(/\s/, ".");
      $(cn).prop('checked', false);
      $(this).prop('checked', checked);
   });

   var displayNewConfiguration = function(equipList) {
      $("table.setup").empty();
      var rows = "";
      $.each(equipList, function(idx,val) {
         rows += "<tr>";
         rows += "<td>"+val.type+"</td>";
         rows += "<td>"+val.name+"</td>";
         rows += "<td>"+val.serial_number+"</td>";
         rows += "</tr>";
      });
      $( rows ).prependTo( $("table.setup") );
   };

   $(".workstation.add").on("click", function() {
      var name = prompt("Enter a name for the new workstation");
      if ( name.length === 0) return;

      $.ajax({
         url: "/admin/workstations",
         method: "POST",
         data: {name: name},
         complete: function(jqXHR, textStatus) {
            if (textStatus != "success") {
               alert("Unable to create new workstation. Please try again later");
            } else {
               $( jqXHR.responseJSON.html ).prependTo( $("table.workstations") );
               $("tr.workstation").removeClass("selected");
               $("tr.workstation[data-id='"+jqXHR.responseJSON.id+"']").addClass("selected");
               displayNewConfiguration([]);
               $(".assign-equipment").removeClass("disabled");
            }
         }
      });
   });

   $("table.workstations").on("click", ".equipment-status",  function(e) {
      e.stopPropagation();
      e.preventDefault();

      var statusIcon = $(this);
      var active = statusIcon.hasClass("active");
      var tr = $(this).closest("tr");
      $.ajax({
         url: "/admin/workstations/"+tr.data("id"),
         method: "PUT",
         data: {active: !active},
         complete: function(jqXHR, textStatus) {
            if (textStatus != "success") {
               alert("Unable to change workstation activation status:\n\n"+jqXHR.responseText);
            } else {
               if ( active ) {
                  statusIcon.removeClass("active");
                  statusIcon.addClass("inactive");
               } else {
                  statusIcon.addClass("active");
                  statusIcon.removeClass("inactive");
               }
            }
         }
      });
   });

   $("table.workstations").on("click", ".trash.ts-icon",  function(e) {
      var resp = confirm("Are you sure you want to retire this workstation?");
      if ( !resp ) return;
      e.stopPropagation();
      e.preventDefault();

      var tr = $(this).closest("tr");
      $.ajax({
         url: "/admin/workstations/"+tr.data("id"),
         method: "DELETE",
         complete: function(jqXHR, textStatus) {
            if (textStatus != "success") {
               alert("Unable to retire workstation:\n\n"+jqXHR.responseText);
            } else {
               tr.remove();
               displayNewConfiguration([]);
               $(".assign-equipment").removeClass("disabled");
               $(".assign-equipment").addClass("disabled");
            }
         }
      });
   });

   $("table.equipment").on("click", ".trash.ts-icon",  function() {
      var resp = confirm("Are you sure you want to retire this equipment?");
      if ( !resp ) return;
      var tr = $(this).closest("tr");
      $.ajax({
         url: "/admin/equipment/"+tr.data("id"),
         method: "DELETE",
         complete: function(jqXHR, textStatus) {
            if (textStatus != "success") {
               alert("Unable to retire equipment:\n\n"+jqXHR.responseText);
            } else {
               tr.remove();
            }
         }
      });
   });

   $("table.workstations").on("click", "tr.workstation",  function() {
      $("tr.workstation").removeClass("selected");
      $(this).addClass("selected");
      var equipList = $(this).data("setup");
      displayNewConfiguration(equipList);
      $(".sel-cb").prop('checked', false);
      $.each(equipList, function(idx,val) {
         $(".sel-cb[data-id='"+val.id+"']").prop('checked', true);
      });
      $(".assign-equipment").removeClass("disabled");
   });

   $(".assign-equipment").on("click", function(){
      if ( $(this).hasClass("disabled") ) return;
      var picks = {bodies: null, backs: null, lenses: null, scanners: null};
      var ids = [];
      var failed = false;
      var camera = false;
      for (var className in picks) {
         if ( !picks.hasOwnProperty(className)) continue;
         $("table."+className+" .sel-cb:checked").each( function(idx, ele) {
            if ( picks[className] ) {
               alert("Only one of each type of equipment may be assigned to a workstation");
               failed = true;
               return false;
            } else {
               picks[className] = $(this).data("id");
               ids.push($(this).data("id"));
               if ( className != "scanners") {
                  camera = true;
               } else {
                  if (camera) {
                     alert("A workstation can only have a camera assembly or a scanner, not both");
                     failed = true;
                     return false;
                  }
               }
            }
         });
      }
      if ( failed ) {
         return;
      }
      if ( camera && ids.length != 3) {
         alert("Incomplete camera assembly specified");
         return false;
      }

      var wsId = $("tr.workstation.selected").data("id");
      var data = {workstation: wsId, equipment: ids, camera: camera};
      var btn = $(this);
      btn.addClass("disabled");
      var setup = $("table.setup");
      $.ajax({
         url: "/admin/equipment/assign",
         method: "POST",
         data: data,
         complete: function(jqXHR, textStatus) {
            btn.removeClass("disabled");
            if (textStatus != "success") {
               alert("Unable to assign equipment. Please try again later");
            } else {
               displayNewConfiguration(jqXHR.responseJSON);
               $("tr.workstation.selected").data("setup", jqXHR.responseJSON);
            }
         }
      });
   });
});
