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
      // TODO
   });

   $("tr.workstation").on("click", function() {
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
