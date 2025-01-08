/**
 * @file
 * JavaScript for dg_autologout.
 */

(function ($, Drupal, cookies) {

  'use strict';

  /**
   * Used to lower the cpu burden for activity tracking on browser events.
   *
   * @param {function} f
   *   The function to debounce.
   */
  function debounce(f) {
      let timeout;
      return function () {
          let savedContext = this;
          let savedArguments = arguments;
          let finalRun = function () {
              timeout = null;
              f.apply(savedContext, savedArguments);
          };
          if (!timeout) {
            f.apply(savedContext, savedArguments);
          }
          clearTimeout(timeout);
          timeout = setTimeout(finalRun, 500);
      };
  }

  /**
   * Attaches the batch behavior for dg_autologout.
   *
   * @type {Drupal~behavior}
   */
  Drupal.behaviors.dg_autologout = {
    attach: function (context, settings) {
      if (context !== document) {
        return;
      }

      let paddingTimer;
      let theDialog;
      let t;
      let localSettings;

      // Timer to keep track of activity resets.
      let activityResetTimer;

      // Prevent settings being overridden by ajax callbacks by cloning it.
      localSettings = jQuery.extend(true, {}, settings.dg_autologout);

      // Add timer element to prevent detach of all behaviours.
      let timerMarkup = $('<div id="dg-timer"></div>').hide();
      $('body').append(timerMarkup);

      if (localSettings.refresh_only) {
        // On pages where user shouldn't be logged out, don't set the timer.
        t = setTimeout(keepAlive, localSettings.timeout);
      }
      else {
        settings.activity = false;
        if (localSettings.logout_regardless_of_activity) {
          // Ignore users activity and set timeout.
          let timestamp = Math.round((new Date()).getTime() / 1000);
          let login_time = cookies.get("Drupal.visitor.dg_autologout_login");
          let difference = (timestamp - login_time) * 1000;

          t = setTimeout(init, localSettings.timeout - difference);
        }
        else {
          // Bind formUpdated events to preventAutoLogout event.
          $('body').bind('formUpdated', debounce(function (event) {
            $(event.target).trigger('preventAutologout');
          }));

          // Bind formUpdated events to preventAutoLogout event.
          $('body').bind('mousemove', debounce(function (event) {
            $(event.target).trigger('preventAutologout');
          }));

          // Replaces the CKEditor5 check because keyup should always prevent autologout.
          document.addEventListener('keyup', debounce(function (event) {
            document.dispatchEvent(new Event('preventAutologout'));
          }));

          $('body').bind('preventAutologout', function (event) {
            // When the preventAutologout event fires, we set activity to true.
            settings.activity = true;

            // Clear timer if one exists.
            clearTimeout(activityResetTimer);

            // Set a timer that goes off and resets this activity indicator after
            // half a minute, otherwise sessions never timeouts.
            activityResetTimer = setTimeout(function () {
              settings.activity = false;
            }, 30000);
          });

          // On pages where the user should be logged out, set the timer to popup
          // and log them out.
          setTimeout(function () {
            init();
          }, localSettings.timeout);
        }
      }

      function init() {
        let noDialog = settings.dg_autologout.no_dialog;
        if (settings.activity) {
          refresh();
        }
        else {
          // The user has not been active, ask them if they want to stay logged
          // in and start the logout timer.
          paddingTimer = setTimeout(confirmLogout, localSettings.timeout_padding);
          // While the countdown timer is going, lookup the remaining time. If
          // there is more time remaining (i.e. a user is navigating in another
          // tab), then reset the timer for opening the dialog.
          Drupal.Ajax['dg_autologout.getTimeLeft'].dgAutologoutGetTimeLeft(function (time) {
            if (time > 0) {
              clearTimeout(paddingTimer);
              t = setTimeout(init, time);
            }
            else {
              // Logout user right away without displaying a confirmation dialog.
              if (noDialog) {
                logout();
                return;
              }
              theDialog = dialog();
            }
          });
        }
      }

      function dialog() {
        let disableButtons = settings.dg_autologout.disable_buttons;

        let buttons = {};
        if (!disableButtons) {
          let yesButton = settings.dg_autologout.yes_button;
          buttons[Drupal.t(yesButton)] = function () {
            cookies.set("Drupal.visitor.dg_autologout_login", Math.round((new Date()).getTime() / 1000));
            $(this).dialog("destroy");
            clearTimeout(paddingTimer);
            refresh();
          };

          let noButton = settings.dg_autologout.no_button;
          buttons[Drupal.t(noButton)] = function () {
            $(this).dialog("destroy");
            logout();
          };
        }

        return $('<div id="dg-autologout-confirm">' + localSettings.message + '</div>').dialog({
          modal: true,
          closeOnEscape: false,
          width: localSettings.modal_width,
          dialogClass: 'autologout-dialog',
          title: localSettings.title,
          buttons: buttons,
          close: function (event, ui) {
            logout();
          }
        });
      }

      // A user could have used the reset button on the tab/window they're
      // actively using, so we need to double check before actually logging out.
      function confirmLogout() {
        $(theDialog).dialog('destroy');

        Drupal.Ajax['dg_autologout.getTimeLeft'].dgAutologoutGetTimeLeft(function (time) {
          if (time > 0) {
            t = setTimeout(init, time);
          }
          else {
            logout();
          }
        });
      }

      function triggerLogoutEvent(logoutMethod, logoutUrl) {
        const logoutEvent = new CustomEvent('dg_autologout', {
          detail: {
            logoutMethod: logoutMethod,
            logoutUrl: logoutUrl,
          },
        });
        document.dispatchEvent(logoutEvent);
      }

      function logout() {
        if (localSettings.use_alt_logout_method) {
          let logoutUrl = drupalSettings.path.baseUrl + "dg_autologout_alt_logout";
          triggerLogoutEvent('alternative', logoutUrl);

          window.location = logoutUrl;
        }
        else {
          $.ajax({
            url: drupalSettings.path.baseUrl + "dg_autologout_ajax_logout",
            type: "POST",
            beforeSend: function (xhr) {
              xhr.setRequestHeader('X-Requested-With', {
                toString: function () {
                  return '';
                }
              });
            },
            success: function () {
              let logoutUrl = localSettings.redirect_url;
              triggerLogoutEvent('normal', logoutUrl);

              window.location = logoutUrl;
            },
            error: function (XMLHttpRequest, textStatus) {
              if (XMLHttpRequest.status === 403 || XMLHttpRequest.status === 404) {
                window.location = localSettings.redirect_url;
              }
            }
          });
        }
      }

      /**
       * Get the remaining time.
       *
       * Use the Drupal ajax library to handle get time remaining events
       * because if using the JS Timer, the return will update it.
       *
       * @param function callback(time)
       *   The function to run when ajax is successful. The time parameter
       *   is the time remaining for the current user in ms.
       */
      Drupal.Ajax.prototype.dgAutologoutGetTimeLeft = function (callback) {
        let ajax = this;

        // Store the original success temporary to be called later.
        const originalSuccess = ajax.options.success;
        ajax.options.submit = {
          uactive: settings.activity
        };
        ajax.options.success = function (response, status, xmlhttprequest) {
          if (typeof response == 'string') {
            response = $.parseJSON(response);
          }
          if (typeof response[0].command === 'string' && response[0].command === 'alert') {
            // In the event of an error, we can assume user has been logged out.
            window.location = localSettings.redirect_url;
          }

          // Loop through response to get correct keys.
          for (let key in response) {
            if (response[key].command === "settings" && typeof response[key].settings.time !== 'undefined') {
              callback(response[key].settings.time);
            }
            if (response[key].command === "insert" && response[key].selector === '#timer' && typeof response[key].data !== 'undefined') {
              response[key].data = '<div id="dg-timer" style="display: none;">' + response[key].data + '</div>';
            }
          }

          // Let Drupal.ajax handle the JSON response.
          return originalSuccess.call(ajax, response, status, xmlhttprequest);
        };

        try {
          $.ajax(ajax.options);
        }
        catch (e) {
          ajax.ajaxing = false;
        }
      };

      Drupal.Ajax['dg_autologout.getTimeLeft'] = Drupal.ajax({
        base: null,
        element: document.body,
        url: drupalSettings.path.baseUrl + 'dg_autologout_ajax_get_time_left',
        submit: {
          uactive: settings.activity
        },
        event: 'dg_autologout.getTimeLeft',
        error: function (XMLHttpRequest, textStatus) {
          // Disable error reporting to the screen.
        },
      });

      /**
       * Handle refresh event.
       *
       * Use the Drupal ajax library to handle refresh events because if using
       * the JS Timer, the return will update it.
       *
       * @param function timerFunction
       *   The function to tell the timer to run after its been restarted.
       */
      Drupal.Ajax.prototype.dgAutologoutRefresh = function (timerfunction) {
        let ajax = this;

        if (ajax.ajaxing) {
          return false;
        }

        // Store the original success temporary to be called later.
        const originalSuccess = ajax.options.success;
        ajax.options.success = function (response, status, xmlhttprequest) {
          if (typeof response === 'string') {
            response = $.parseJSON(response);
          }
          if (typeof response[0].command === 'string' && response[0].command === 'alert') {
            // In the event of an error, we can assume the user has been logged out.
            window.location = localSettings.redirect_url;
          }

          t = setTimeout(timerfunction, localSettings.timeout);

          // Wrap response data in timer markup to prevent detach of all behaviors.
          response[0].data = '<div id="dg-timer" style="display: none;">' + response[0].data + '</div>';

          // Let Drupal.ajax handle the JSON response.
          return originalSuccess.call(ajax, response, status, xmlhttprequest);
        };

        try {
          $.ajax(ajax.options);
        }
        catch (e) {
          ajax.ajaxing = false;
        }
      };

      Drupal.Ajax['dg_autologout.refresh'] = Drupal.ajax({
        base: null,
        element: document.body,
        url: drupalSettings.path.baseUrl + 'dg_autologout_ajax_set_last',
        event: 'dg_autologout.refresh',
        error: function (XMLHttpRequest, textStatus) {
          // Disable error reporting to the screen.
        }
      });

      function keepAlive() {
        if (!document.hidden) {
          Drupal.Ajax['dg_autologout.refresh'].dgAutologoutRefresh(keepAlive);
        } else {
          t = setTimeout(keepAlive, localSettings.timeout);
        }
      }

      function refresh() {
        Drupal.Ajax['dg_autologout.refresh'].dgAutologoutRefresh(init);
      }

      // Check if the page was loaded via a back button click.
      let $dirty_bit = $('#autologout-cache-check-bit');
      if ($dirty_bit.length !== 0) {
        if ($dirty_bit.val() === '1') {
          // Page was loaded via back button click, we should refresh the timer.
          refresh();
        }

        $dirty_bit.val('1');
      }
    }
  };

})(jQuery, Drupal, window.Cookies);
