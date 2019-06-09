#!/bin/bash
# Output Chrome Bookmarks to /Library/Google/bookmarks.html

if [ ! -d "/Library/Google" ]
then
    mkdir "/Library/Google"
fi

(
sudo cat <<'EOD'
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<!-- This is an automatically generated file.
     It will be read and overwritten.
     DO NOT EDIT! -->
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
    <DT><H3 ADD_DATE="1544871663" LAST_MODIFIED="1559916538" PERSONAL_TOOLBAR_FOLDER="true">Bookmarks Bar</H3>
    <DL><p>
		    <DT><A HREF="https://www.office.com/launch/word" ADD_DATE="1544871663" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABcUlEQVQ4jZ2Tuy+DURiHn/P5WpdFwiiKqATtl1QNTRdMwmigQSwS4pLwT9j8AZKGDgahgsUgYjQ1JneJWwexuMRtaeW8Bp8G/VTTJ+ck5wy/c5735D0Km3BvvPTV9dSsNa0i2hKtLQRLRFcgcLo+qXBA+ftj6yixELwiGkQQe36uNQgYpvk7m0LJnImix+nk3xytjP7Yp9+1OzA4P27kE3bCZRoA7iyvv/BFoo42BoBhKA6WhgE4XB6hM1RHY20lx6tjP0Jf8zsmgNYCQFmJC4CQv4pid1FeBpkSthPXtLVUs3dyS1NtJS9vKWYWdh1DWQYAp9cPdIXr2UkkGer20VBTwU7iMn+Ds+Q9U31BFjf3Ob95pCPoYXp2K3+D46u7T5PkPUcXd7S3eEi/638NlH8gJmCPHJ14sjaRdbsvEqXgRvqi4APs8lImwgYKC/DmCnx/A5sUSuYyXzTcGy99cj1bSktARAdEi4WIJaLLc33nD/9DsQsnDbsgAAAAAElFTkSuQmCC">Word</A>
        <DT><A HREF="https://www.office.com/launch/powerpoint" ADD_DATE="1544871663" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABrElEQVQ4jZ2Tv09TURTHP/e+h1LaWsKCIQQXAkh4TSOMEgwLAdJNJhyMm6saTUz8D4zGiZWVBePEr7AhIQwwtA3yiJSBmLiQQGlf09p7HGyfvvaFNH6Xm/s993zvOd97j6KO3YX+SOwyNgpmHDGOoBxEHIEeREhtf1eEwM7OjqyCcSgwKNqACIICCTveCpWdGxaEemJ9FZAmTlu6OddDyZLd3j3gbLiBvamUI7l08rkv2/v0BWNrx4ytuzgbLgNvP6Lsjr8JXgnjlTh99YTymYu+1QkQ0U2q/Pj0juuDHbofzdM9nfZj3xYnEVOjmNnn/P0bnw+0INUqF2sreHmX2IOH3O67FyjbisZbWmlxxk70kJiaA6CcP/b5WrFAZmaI7Ox9asVCeAVWNM7Iyh4A1wc7XH7d8mNKW6A1d5+9xIrGwwWMVyL/ehFTqeLl3fpb/sHol0OUtgLGtnpgangnuX/zfOTSycC+4cV//4MGfBN/Ln/g6PFEu3rIrypApe0KMjNDzVRFKZZsRH0G4wCDNwkkN09Cp9Endxf6I3euuhwjpBSSMkJjnBM3jfNvrDmsKUw7RnQAAAAASUVORK5CYII=">PowerPoint</A>
        <DT><A HREF="https://www.office.com/launch/excel" ADD_DATE="1544871663" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABqUlEQVQ4jY2TsUscQRSHv929PbVRkuAR5BRdDgmRiYJGEbRUsmclIoRUJqlMZwwXS/+BS8AEvMJGEAQLxebA07MwFlZaGAIicgaSiCRE1E69fRa6i+vtnf5gmDcD85tv3rynca3oyGBFmX781IFWR0RpIkocUQgPEeHnl1WNAGnWmD0vIgqRGALiCMjVuIoBETTTuH32DGEyBPQHOd9WLpnxrc/zF+HGRHxYv89hgIbRXm9uGO3FNEIAYc/gZbvN3LskphGi3Cwj83GK1NvxAoJcMuOj8Qx+HR3SVt+E/aybgec9WNW1fE5PFyVwFXKD9d1Nvv/e5VVnH48rH7G4lWXnIBdIcFO+HHzNztJhKWoeRJhYmimZgwICV3nHQdd0wobp27+TwNB1EvYb0ttrHJ7843186F4EnsFAaw9WdZRUdo7pb4u8UF001z0JJAj8hVikjvnNFX782WN2I83f0/986Ht9J4Fmjdki4pZv8VLen8j6nnSev6AxET8rSGIx3bz1Wl4vLAAKiJUy2P+0HNyNbhAdGawwzRNFXlpEaBHHUYgohKpS7XwJg0q9cUxsKk4AAAAASUVORK5CYII=">Excel</A>
    </DL><p>
</DL><p>
EOD
) > "/Library/Google/bookmarks.html"

# Output Chrome Master Preferences to /Library/Google/Google Chrome Master Preferences

if [ ! -d "/Library/Google" ]
then
    mkdir "/Library/Google"
fi

(
sudo cat <<'EOD'
{
	"homepage": "https://www.google.com",
	"homepage_is_newtabpage": true,
	"browser": {
		"show_home_button": false,
		"check_default_browser": false,
		"has_seen_welcome_page": true
	},
	"bookmark_bar": {
		"show_apps_shortcut": false,
		"show_on_all_tabs": true
	},
	"distribution": {
		"import_bookmarks": false,
		"import_bookmarks_from_file": "/Library/Google/bookmarks.html",
		"suppress_first_run_bubble": true,
		"show_welcome_page": false,
		"skip_first_run_ui": true,
		"import_history": false,
		"import_home_page": false,
		"import_search_engine": false,
		"importautofillformdata": false,
		"suppress_first_run_default_browser_prompt": true,
		"require_eula": false
	},
	"sync_promo": {
		"show_on_first_run_allowed": false,
		"user_skipped": true
	},
	"first_run_tabs": [
		"https://www.google.no/"
	]
}
EOD
) > "/Library/Google/Google Chrome Master Preferences"
