jQuery.noConflict();
(function($) {

$(function() {
    jQuery.validator.addMethod("password_regex",
        function(password, element) {
            return (this.optional(element) ||
                    /^[\x21-\x7f]+$/.test(password)
                   );
        }, "密碼包含不可使用字元\\x21-\\x7f"
    );


    $("#apply_email").validate({
        rules: {
            uid: {
                required:       true
            },
            password: {
                password:       "#username"
            },
            password_confirm: {
                required:       true,
                equalTo:        "#password",
                password_regex: true,
                minlength:      8,
                maxlength:      16
            }
        }
    });

    $.validator.passwordRating.messages = {
	"similar-to-username": "密碼與帳號名稱相似 (Similar to username)",
	"too-short"          : "密碼太短 (Too short)",
	"very-weak"          : "密碼強度很弱 (Very weak)",
	"weak"               : "密碼強度弱 (Weak)",
	"good"               : "密碼強度好 (Good)",
	"strong"             : "密碼強度很強 (Strong)"
    }

//    $("#password").valid();
});

})(jQuery);
