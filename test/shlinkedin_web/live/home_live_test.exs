defmodule ShlinkedinWeb.HomeLiveTest do
  use ShlinkedinWeb.ConnCase

  import Phoenix.LiveViewTest
  import Shlinkedin.TimelineFixtures

  alias Shlinkedin.Timeline
  alias Shlinkedin.Points

  @create_attrs %{
    body: "some body"
  }

  describe "home page as ANONYMOUS" do
    test "initial render with anon user", %{conn: conn} do
      {:ok, view, _html} = conn |> live("/home")

      assert render(view) =~ "Start a post"
    end

    test "like post as anon user", %{conn: conn} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      post = post_fixture()

      assert view |> element("#post-#{post.id}-like-Invest") |> render_click()

      assert_patch(view, Routes.home_index_path(conn, :index))
      assert view |> render() =~ "You must join"
    end

    test "start a post as anon user", %{conn: conn} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      assert view |> element("a", "Start a post") |> render_click()
      assert view |> render() =~ "You must join"
    end

    test "create ad as anon user", %{conn: conn} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      assert view |> element("a", "Create Ad") |> render_click()
      assert view |> render() =~ "You must join"
    end

    test "write headlines as anon user", %{conn: conn} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      assert view |> element("a", "Write Headline") |> render_click()
      assert view |> render() =~ "You must join"
    end

    test "clap headline as anon user", %{conn: conn} do
      headline = headline_fixture()

      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      assert view |> render() =~ "👏"

      view |> element("#article-#{headline.id}-clap") |> render_click()
      assert view |> render() =~ "You must join"
    end
  end

  describe "registered user home page" do
    setup :register_user_and_profile

    test "initial render with user and profile", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> live("/home")

      assert render(view) =~ "Start a post"
    end

    test "create new post and lists them", %{conn: conn, profile: profile} do
      {:ok, post} = Timeline.create_post(profile, @create_attrs, %Timeline.Post{})

      {:ok, _view, html} =
        live(conn, Routes.home_index_path(conn, :index, type: "new", time: "week"))

      assert html =~ post.body
      assert html =~ "ShlinkNews"
    end

    test "saves new post", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> live(Routes.home_index_path(conn, :index))

      assert view |> element("a", "Start a post") |> render_click() =~
               "Create a post"

      assert_patch(view, Routes.home_index_path(conn, :new))

      {:ok, _, html} =
        view
        |> form("#post-form", post: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Post created successfully"
      assert html =~ "some body"
    end

    test "deletes post", %{conn: conn, profile: profile} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      {:ok, post} = Timeline.create_post(profile, %{body: "test"}, %Timeline.Post{})

      assert view |> element("#options-menu-#{post.id}") |> render_click()

      assert view |> element("#post-#{post.id} a", "Delete") |> render_click()

      refute view
             |> element("#post-#{post.id} a", "Delete")
             |> has_element?()
    end

    test "like post", %{conn: conn, profile: profile} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      {:ok, post} = Timeline.create_post(profile, %{body: "test"}, %Timeline.Post{})

      assert view |> element("#post-#{post.id}-like-Invest") |> render_click()

      assert view |> element("#post-likes-#{post.id}") |> render() =~ "1"
    end

    test "like post twice", %{conn: conn, profile: profile} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      {:ok, post} = Timeline.create_post(profile, %{body: "test"}, %Timeline.Post{})

      assert Shlinkedin.Profiles.get_profile_by_profile_id(profile.id).points == %Money{
               amount: 100,
               currency: :SHLINK
             }

      assert view |> element("#post-#{post.id}-like-Milk") |> render_click()

      assert view |> element("#post-likes-#{post.id}") |> render() =~ "1 • 1 person"

      assert Shlinkedin.Profiles.get_profile_by_profile_id(profile.id).points == %Money{
               amount: 2100,
               currency: :SHLINK
             }

      assert view |> element("#post-#{post.id}-like-Milk") |> render_click()
      assert view |> element("#post-likes-#{post.id}") |> render() =~ "2 • 1 person"

      assert Shlinkedin.Profiles.get_profile_by_profile_id(profile.id).points == %Money{
               amount: 2100,
               currency: :SHLINK
             }
    end

    test "see likes for a post", %{conn: conn, profile: profile} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      {:ok, post} = Timeline.create_post(profile, %{body: "test"}, %Timeline.Post{})

      view |> element("#post-#{post.id}-like-Milk") |> render_click()

      assert view |> element("#post-likes-#{post.id}") |> render() =~ "1 • 1 person"

      view
      |> element("#post-likes-#{post.id}")
      |> render_click() =~
        "Reactions"

      assert view |> render() =~ "Milk"

      {:ok, view, _html} =
        view
        |> element("##{profile.slug}")
        |> render_click()
        |> follow_redirect(conn)

      assert view |> render =~ profile.persona_name
    end

    test "write comment", %{conn: conn, profile: profile} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      {:ok, post} = Timeline.create_post(profile, %{body: "test"}, %Timeline.Post{})

      # todo: figure out why this doesn't work
      # view
      # |> element("#new-comment-#{post.id}")
      # |> render_click()
      # |> IO.inspect(label: "rendered")

      assert view |> element("#first-comment-btn-#{post.id}") |> render_click() =~
               "Add a comment..."

      assert_patch(view, Routes.home_index_path(conn, :new_comment, post.id))

      view |> element("#first-comment-btn-#{post.id}") |> render_click()

      view
      |> form("#comment-form", comment: %{body: "yay first comment!"})
      |> render_submit()

      assert view |> render() =~ "yay first comment!"
      assert view |> render() =~ "you commented! +1 shlink points"
    end

    test "like comment", %{conn: conn, profile: profile} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      {:ok, post} = Timeline.create_post(profile, %{body: "test"}, %Timeline.Post{})
      {:ok, post} = Timeline.create_comment(profile, post, %{body: "yay first comment!"})

      comment = post.comments |> Enum.at(0)

      assert view |> render() =~ "yay first comment!"

      assert view |> element("#comment-#{comment.id}-like-btn-Slap") |> render_click() =~ "1"
      assert view |> element("#comment-#{comment.id}-like-btn-Warm") |> render_click() =~ "2"
      assert view |> element("#comment-#{comment.id}-like-btn-Slap") |> render_click() =~ "3"

      view |> element("#show-comment-#{comment.id}-likes", "3") |> render_click()

      assert_patch(
        view,
        Routes.home_index_path(conn, :show_comment_likes, comment.id)
      )

      assert view |> render =~ "Comment Reactions"
    end

    test "deletes comment", %{conn: conn, profile: profile} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      {:ok, post} = Timeline.create_post(profile, %{body: "test"}, %Timeline.Post{})
      {:ok, post} = Timeline.create_comment(profile, post, %{body: "yay first comment!"})

      comment = post.comments |> Enum.at(0)

      assert view |> render() =~ "yay first comment!"

      {:ok, view, _html} =
        view
        |> element("#delete-comment-#{comment.id}")
        |> render_click()
        |> follow_redirect(conn)

      refute view
             |> element("#delete-comment-#{comment.id}")
             |> has_element?()
    end

    test "click write my first post", %{conn: conn} do
      {:ok, view, _html} = live(conn, Routes.home_index_path(conn, :index))

      {:ok, view, _html} =
        view
        |> element("a", "Write your first post")
        |> render_click()
        |> follow_redirect(conn)

      {:ok, _, html} =
        view
        |> form("#post-form", post: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Post created successfully"
      assert html =~ "some body"
    end

    test "create new headline", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> live(Routes.home_index_path(conn, :index))

      assert view |> element("a", "+ Headline") |> render_click() =~ "New Headline"

      assert_patch(view, Routes.home_index_path(conn, :new_article))

      {:ok, _, html} =
        view
        |> form("#article-form", article: %{headline: "Hi there"})
        |> render_submit()
        |> follow_redirect(conn, Routes.home_index_path(conn, :index))

      assert html =~ "Headline created successfully"
      assert html =~ "Hi there"
    end

    test "test clap headline", %{conn: conn, profile: profile} do
      {:ok, headline} =
        Shlinkedin.News.create_article(profile, %Shlinkedin.News.Article{}, %{
          headline: "this just in"
        })

      {:ok, view, _html} =
        conn
        |> live(Routes.home_index_path(conn, :index))

      assert profile.points.amount == 100

      assert view |> render() =~ "👏"

      view |> element("#article-#{headline.id}-clap") |> render_click()

      assert view |> render() =~ "✖"
      assert view |> render() =~ "claps"

      # your SPs go down -1000
      profile = Shlinkedin.Profiles.get_profile_by_profile_id(profile.id)
      assert profile.points.amount == -9900
    end

    test "test clap headline from someone else", %{conn: conn} do
      # create profiles
      other_profile = Shlinkedin.ProfilesFixtures.profile_fixture()

      {:ok, headline} =
        Shlinkedin.News.create_article(other_profile, %Shlinkedin.News.Article{}, %{
          headline: "this just in"
        })

      {:ok, view, _html} =
        conn
        |> live(Routes.home_index_path(conn, :index))

      assert view |> render() =~ "👏"

      view |> element("#article-#{headline.id}-clap") |> render_click()

      assert view |> render() =~ "✖"
      assert view |> render() =~ "claps"

      # # reload other profile
      other_profile = Shlinkedin.Profiles.get_profile_by_profile_id(other_profile.id)
      # # now, one unclap
      assert other_profile.points.amount ==
               100 + Points.get_rule_amount(:new_headline).amount +
                 Points.get_rule_amount(:vote).amount

      # unclap
      view |> element("#article-#{headline.id}-clap") |> render_click()
      refute view |> render() =~ "✖"

      other_profile = Shlinkedin.Profiles.get_profile_by_profile_id(other_profile.id)

      assert other_profile.points.amount ==
               100 + Points.get_rule_amount(:new_headline).amount +
                 Points.get_rule_amount(:vote).amount + Points.get_rule_amount(:unvote).amount
    end

    test "test delete headline", %{conn: conn, profile: profile} do
      {:ok, headline} =
        Shlinkedin.News.create_article(profile, %Shlinkedin.News.Article{}, %{
          headline: "this just in"
        })

      {:ok, view, _html} =
        conn
        |> live(Routes.home_index_path(conn, :index))

      assert view |> render() =~ "this just in"

      {:ok, view, _html} =
        view
        |> element("#article-#{headline.id}-delete")
        |> render_click()
        |> follow_redirect(conn, Routes.home_index_path(conn, :index))

      assert view |> render() =~ "Headline deleted"
      refute view |> render() =~ "this just in"
    end

    test "test show/hide levels", %{conn: conn, profile: profile} do
      assert profile.show_levels == true

      {:ok, view, _html} =
        conn
        |> live(Routes.home_index_path(conn, :index))

      assert view |> render() =~ "📝 New Hire"
      refute view |> element("#toggle-levels") |> render_click() =~ "📝 New Hire"

      assert Shlinkedin.Profiles.get_profile_by_profile_id(profile.id).show_levels == false
    end

    test "select different feed types", %{conn: conn, profile: profile} do
      {:ok, view, _html} = conn |> live(Routes.home_index_path(conn, :index))

      assert profile.feed_type == "featured"
      assert profile.feed_time == "week"

      view
      |> form("#sort-feed", %{type: "new"})
      |> render_change()

      assert Shlinkedin.Profiles.get_profile_by_profile_id(profile.id).feed_type == "new"

      view
      |> form("#sort-feed", %{time: "today"})
      |> render_change()

      assert Shlinkedin.Profiles.get_profile_by_profile_id(profile.id).feed_time == "today"
    end
  end

  describe "discord alerts" do
    setup :register_user_and_profile

    test "close alert", %{conn: conn, profile: _profile} do
      {:ok, view, _html} = conn |> live(Routes.home_index_path(conn, :index))

      assert view |> render() =~ "Join the Discord"

      view
      |> element("#close-discord")
      |> render_click()

      refute view |> render() =~ "Join the Discord"

      # but when we reload the page it's still there
      {:ok, view, _html} = conn |> live(Routes.home_index_path(conn, :index))
      assert view |> render() =~ "Join the Discord"
    end

    test "join discord", %{conn: conn, profile: profile} do
      {:ok, view, _html} = conn |> live(Routes.home_index_path(conn, :index))

      assert view |> render() =~ "Join the Discord"
      assert profile.points.amount == 100

      view |> element("#join-discord") |> render_click()

      # now that we've joined...
      discord_points = Shlinkedin.Points.get_rule_amount(:join_discord).amount
      updated_prof = Shlinkedin.Profiles.get_profile_by_profile_id(profile.id)
      assert updated_prof.joined_discord == true
      assert updated_prof.points.amount == 100 + discord_points

      assert (Shlinkedin.Profiles.list_notifications(updated_prof.id, 1)
              |> Enum.at(0)).body == "Memo: For joining the discord"

      # reload the page
      {:ok, view, _html} = conn |> live(Routes.home_index_path(conn, :index))

      refute view |> render() =~ "Join the Discord"
    end

    test "already on discord", %{conn: conn, profile: profile} do
      {:ok, view, _html} = conn |> live(Routes.home_index_path(conn, :index))

      assert view |> render() =~ "Join the Discord"
      assert profile.points.amount == 100

      view |> element("#already-discord") |> render_click()

      updated_prof = Shlinkedin.Profiles.get_profile_by_profile_id(profile.id)

      assert (Shlinkedin.Profiles.list_notifications(updated_prof.id, 1)
              |> Enum.at(0)).body == "Memo: For joining the discord"

      # reload the page
      {:ok, view, _html} = conn |> live(Routes.home_index_path(conn, :index))

      refute view |> render() =~ "Join the Discord"
    end
  end
end
